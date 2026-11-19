import Foundation

/// A finding: something Device check or Diagnose believes about the device, with its evidence.
struct Finding: Identifiable, Hashable {
    enum Severity: Int, Comparable { case info = 0, attention = 1, problem = 2
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }
    var id: String
    var title: String
    var reason: String
    var severity: Severity
    var evidence: [Fact]
    var fix: OperationPlan?
    var symptomID: String?
    var confidence: Int?       // nil = observed fact
}

/// A known symptom: what people see, what usually causes it, and the safest fix.
struct Symptom: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let keywords: [String]
    let cause: String
    let culprit: PrefKey?
    let culpritValue: PlistValue?
    let fixLabel: String
    let tier: Tier
    let confidence: Int
    let userCheck: String
    let needsRespring: Bool

    func matchScore(_ text: String) -> Int {
        let t = text.lowercased()
        var score = 0
        for k in keywords where t.contains(k) { score += k.count > 4 ? 3 : 2 }
        if t.contains(title.lowercased()) { score += 6 }
        return score
    }

    /// Fix plan given what's currently on the device (`current`), or the expected value if unknown.
    func plan(current: PlistValue?) -> OperationPlan? {
        guard let culprit else { return nil }
        let known = current != nil
        let change = Change(label: fixLabel, target: culprit, before: current ?? culpritValue, after: nil, tier: tier, beforeKnown: known)
        return OperationPlan(title: "Fix: " + title.lowercased(), kind: .fix, changes: [change], needsRespring: needsRespring, userCheck: userCheck)
    }
}

enum Knowledge {
    static let sb = "com.apple.springboard"
    static let bk = "com.apple.backboardd"
    static let pb = "com.apple.Pasteboard"
    static let gp = ".GlobalPreferences"

    /// Seeded from real reports (including the 2026-11-18 GoldenNugget logs). Confidence is how often the culprit explains the symptom.
    static let symptoms: [Symptom] = [
        Symptom(id: "clock-941", title: "Clock stuck at 09:41", detail: "Status bar or Lock Screen always shows 9:41 and a fixed date",
                symbol: "clock.badge.exclamationmark",
                keywords: ["9:41", "09:41", "941", "clock", "time", "stuck", "frozen", "date", "jan"],
                cause: "A status-bar override (Apple's demo time) was left behind, usually by a recording/status-bar tweak or a restored status-bar archive.",
                culprit: PrefKey(domain: sb, key: "SBShowStatusBarOverridesForRecording"), culpritValue: .bool(true),
                fixLabel: "Stop showing status-bar overrides", tier: .reversible, confidence: 86,
                userCheck: "Is your clock showing the right time now?", needsRespring: true),
        Symptom(id: "green-line", title: "Green or red line on Lock Screen", detail: "A thin coloured bar across the top of the Lock Screen",
                symbol: "line.horizontal.3.decrease",
                keywords: ["green", "red", "line", "bar", "top", "lock screen", "lockscreen", "stripe"],
                cause: "SpringBoard's authentication engineering indicator is on. It draws a red/green line showing unlock state.",
                culprit: PrefKey(domain: sb, key: "SBShowAuthenticationEngineeringUI"), culpritValue: .bool(true),
                fixLabel: "Turn off the authentication line", tier: .reversible, confidence: 92,
                userCheck: "Has the line gone from the Lock Screen?", needsRespring: true),
        Symptom(id: "touch-dots", title: "White dots where I touch", detail: "Circles follow your finger everywhere",
                symbol: "hand.point.up.left",
                keywords: ["dot", "dots", "circle", "touch", "finger", "tap"],
                cause: "backboardd is visualising touches (a screen-recording aid).",
                culprit: PrefKey(domain: bk, key: "BKDigitizerVisualizeTouches"), culpritValue: .bool(true),
                fixLabel: "Stop showing touches", tier: .reversible, confidence: 95,
                userCheck: "Have the dots gone?", needsRespring: true),
        Symptom(id: "no-logo", title: "No Apple logo on restart", detail: "Black screen instead of the logo when the interface restarts",
                symbol: "applelogo",
                keywords: ["logo", "apple logo", "boot", "restart", "respring", "black"],
                cause: "The 'hide logo during interface restart' preference is on.",
                culprit: PrefKey(domain: bk, key: "BKHideAppleLogoOnLaunch"), culpritValue: .bool(true),
                fixLabel: "Show the logo again", tier: .reversible, confidence: 80,
                userCheck: "Does the logo show on the next restart?", needsRespring: false),
        Symptom(id: "never-locks", title: "Screen never locks while charging", detail: "Display stays on whenever it's plugged in",
                symbol: "bolt.badge.clock",
                keywords: ["lock", "dim", "charging", "awake", "screen on", "never", "auto-lock"],
                cause: "SpringBoard is told not to dim or lock on AC power.",
                culprit: PrefKey(domain: sb, key: "SBDontDimOrLockOnAC"), culpritValue: .bool(true),
                fixLabel: "Let the screen lock while charging", tier: .reversible, confidence: 84,
                userCheck: "Does the screen lock on charge now?", needsRespring: true),
        Symptom(id: "paste-noise", title: "Sounds or banners on every paste", detail: "A sound or notice each time you paste",
                symbol: "doc.on.clipboard",
                keywords: ["paste", "clipboard", "sound", "banner", "notice", "copy"],
                cause: "Pasteboard debug options are on (sound on paste / announce all pastes).",
                culprit: PrefKey(domain: pb, key: "PlaySoundOnPaste"), culpritValue: .bool(true),
                fixLabel: "Turn off paste sounds", tier: .reversible, confidence: 78,
                userCheck: "Is pasting quiet again?", needsRespring: false),
        Symptom(id: "clock-glass", title: "Lock Screen clock looks flat", detail: "The glassy clock lost its depth or refraction",
                symbol: "textformat.size",
                keywords: ["clock", "glass", "flat", "lock screen", "font", "liquid"],
                cause: "The 'no liquid clock' global preference is on.",
                culprit: PrefKey(domain: gp, key: "NoLiquidClock"), culpritValue: .bool(true),
                fixLabel: "Restore the glass clock", tier: .caution, confidence: 70,
                userCheck: "Does the clock look right now?", needsRespring: true),
        Symptom(id: "slow-backup", title: "Backups are slow or stall", detail: "Protective backup sits at the same % for minutes, then retries",
                symbol: "tortoise",
                keywords: ["backup", "slow", "stall", "stuck", "retry", "connection reset", "jktcp", "%"],
                cause: "Packet loss in the on-device tunnel stalls the transfer (out-of-order segments, no retransmit), then the device resets the connection. It's transport, not Wi-Fi.",
                culprit: nil, culpritValue: nil,
                fixLabel: "", tier: .reversible, confidence: 75,
                userCheck: "", needsRespring: false),
    ]

    static func match(_ text: String) -> [(Symptom, Int)] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        return symptoms.map { ($0, $0.matchScore(trimmed)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
}
