import Foundation

/// A tweak Assay knows about. Metadata is the product: tier, OS range, how it's verified, and how to recover.
struct Tweak: Identifiable, Hashable {
    enum Kind: Hashable { case toggle, number(min: Double, max: Double, step: Double, unit: String), text(placeholder: String) }
    enum Category: String, CaseIterable, Identifiable {
        case lockScreen = "Lock Screen", display = "Display & touch", system = "System", pasteboard = "Paste", developer = "Developer"
        var id: String { rawValue }
        var symbol: String {
            switch self { case .lockScreen: "lock"; case .display: "hand.tap"; case .system: "gearshape"; case .pasteboard: "doc.on.clipboard"; case .developer: "hammer" }
        }
    }

    let id: String
    let title: String
    let detail: String
    let category: Category
    let target: PrefKey
    let kind: Kind
    /// The value that turns the tweak on. For toggles this is `.bool(true)`.
    let onValue: PlistValue
    let tier: Tier
    let minOS: String?
    let maxOS: String?
    let respring: Bool
    let verification: String
    let recovery: String
    let conflicts: [String]
    /// Tweaks that commonly cause a problem if left on (links to Diagnose).
    let symptomID: String?

    var isToggle: Bool { if case .toggle = kind { return true } else { return false } }

    func availability(osVersion: String) -> Availability {
        if let m = minOS, OSVersion.compare(osVersion, m) == .orderedAscending { return .tooOld(m) }
        if let m = maxOS, OSVersion.compare(osVersion, m) == .orderedDescending { return .tooNew(m) }
        return .supported
    }

    enum Availability: Equatable {
        case supported, tooOld(String), tooNew(String)
        var isSupported: Bool { self == .supported }
        var reason: String? {
            switch self {
            case .supported: return nil
            case .tooOld(let v): return "Needs iOS \(v) or later"
            case .tooNew(let v): return "Not verified after iOS \(v)"
            }
        }
    }
}

enum OSVersion {
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: .numeric)
    }
}

enum TweakCatalog {
    private static let sb = "com.apple.springboard", bk = "com.apple.backboardd", pb = "com.apple.Pasteboard"
    private static let gp = ".GlobalPreferences", ui = "com.apple.UIKit", app = "com.apple.AppStore"
    private static let notes = "com.apple.mobilenotes", airdrop = "com.apple.sharingd"

    static func key(_ d: String, _ k: String) -> PrefKey { PrefKey(domain: d, key: k) }

    /// Seeded from the entries Assay has verified keys, domains and OS gates for. More arrive with signed catalogue updates (2.5).
    static let all: [Tweak] = [
        Tweak(id: "SBHideLowPowerAlerts", title: "Hide low battery alerts", detail: "Stops the 20% and 10% battery pop-ups.",
              category: .system, target: key(sb, "SBHideLowPowerAlerts"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off, or Undo from history.", conflicts: [], symptomID: nil),
        Tweak(id: "SBNeverBreadcrumb", title: "Hide the back-to-app breadcrumb", detail: "Removes the small 'Back to …' link at the top after opening a link in another app.",
              category: .system, target: key(sb, "SBNeverBreadcrumb"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off, or Undo from history.", conflicts: [], symptomID: nil),
        Tweak(id: "SBDontDimOrLockOnAC", title: "Keep screen awake while charging", detail: "The display won't dim or auto-lock while plugged in.",
              category: .system, target: key(sb, "SBDontDimOrLockOnAC"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off. The screen locks normally on the next charge.", conflicts: [], symptomID: "never-locks"),
        Tweak(id: "SBDontLockAfterCrash", title: "Don't lock after a SpringBoard crash", detail: "Skips the passcode prompt after the interface restarts.",
              category: .lockScreen, target: key(sb, "SBDontLockAfterCrash"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off. Your passcode is not affected.", conflicts: [], symptomID: nil),
        Tweak(id: "LockScreenFootnote", title: "Lock Screen message", detail: "Shows your own text at the bottom of the Lock Screen.",
              category: .lockScreen, target: key("SharedDeviceConfiguration", "LockScreenFootnote"), kind: .text(placeholder: "e.g. Property of Joe"),
              onValue: .string(""), tier: .caution, minOS: nil, maxOS: nil, respring: true,
              verification: "Read back from the device configuration file",
              recovery: "Clear the text. If it sticks, use Restore to before Assay.", conflicts: [], symptomID: nil),
        Tweak(id: "NoLiquidClock", title: "Flat Lock Screen clock", detail: "Removes the glass effect from the Lock Screen clock.",
              category: .lockScreen, target: key(gp, "NoLiquidClock"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: "26.0", maxOS: nil, respring: true, verification: "Read back from global preferences",
              recovery: "Turn it off to get the glass clock back.", conflicts: [], symptomID: "clock-glass"),
        Tweak(id: "DisableSecondsHand", title: "Hide the analogue seconds hand", detail: "The clock's second hand stops sweeping.",
              category: .lockScreen, target: key(gp, "DisableSecondsHand"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from global preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: nil),
        Tweak(id: "SBMinimumLockscreenIdleTime", title: "Lock Screen stays on longer", detail: "Seconds the Lock Screen waits before dimming.",
              category: .lockScreen, target: key(sb, "SBMinimumLockscreenIdleTime"), kind: .number(min: 10, max: 300, step: 10, unit: "s"),
              onValue: .int(60), tier: .caution, minOS: nil, maxOS: nil, respring: true,
              verification: "Read back from SpringBoard preferences", recovery: "Remove the value. iOS uses its default.", conflicts: [], symptomID: nil),
        Tweak(id: "BKDigitizerVisualizeTouches", title: "Show touch points", detail: "Draws a dot under each finger. Useful for screen recordings.",
              category: .display, target: key(bk, "BKDigitizerVisualizeTouches"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from backboardd preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: "touch-dots"),
        Tweak(id: "BKHideAppleLogoOnLaunch", title: "Hide the logo on interface restart", detail: "Skips the Apple logo when SpringBoard restarts.",
              category: .display, target: key(bk, "BKHideAppleLogoOnLaunch"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from backboardd preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: "no-logo"),
        Tweak(id: "PlaySoundOnPaste", title: "Play a sound on paste", detail: "A sound each time you paste.",
              category: .pasteboard, target: key(pb, "PlaySoundOnPaste"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from Pasteboard preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: "paste-noise"),
        Tweak(id: "AnnounceAllPastes", title: "Announce every paste", detail: "A banner whenever an app reads the clipboard.",
              category: .pasteboard, target: key(pb, "AnnounceAllPastes"), kind: .toggle, onValue: .bool(true), tier: .reversible,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from Pasteboard preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: "paste-noise"),
        Tweak(id: "SBHomeSidebarIsPinned", title: "Pin the Home Screen sidebar", detail: "Keeps the iPad-style sidebar open on supported layouts.",
              category: .display, target: key(sb, "SBHomeSidebarIsPinned"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: "26.1", maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: nil),
        Tweak(id: "SBShowAuthenticationEngineeringUI", title: "Show the unlock test indicator", detail: "Draws a red/green line on the Lock Screen showing unlock state. Developer aid.",
              category: .developer, target: key(sb, "SBShowAuthenticationEngineeringUI"), kind: .toggle, onValue: .bool(true), tier: .experimental,
              minOS: nil, maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off. This is the usual cause of a stray green or red line.", conflicts: [], symptomID: "green-line"),
        Tweak(id: "SBShowStatusBarOverridesForRecording", title: "Show recording status indicators", detail: "Applies status-bar overrides (Apple's 9:41 demo time) for screen recordings.",
              category: .developer, target: key(sb, "SBShowStatusBarOverridesForRecording"), kind: .toggle, onValue: .bool(true), tier: .experimental,
              minOS: "26.1", maxOS: nil, respring: true, verification: "Read back from SpringBoard preferences",
              recovery: "Turn it off. This is the usual cause of a clock stuck at 9:41.", conflicts: [], symptomID: "clock-941"),
        Tweak(id: "AppStoreDebug", title: "App Store debug menu", detail: "Adds a hidden debug menu to the App Store.",
              category: .developer, target: key(app, "AppStoreDebug"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from App Store preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: nil),
        Tweak(id: "NotesDebugMode", title: "Notes debug mode", detail: "Shows debug information inside Notes.",
              category: .developer, target: key(notes, "NotesDebugMode"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from Notes preferences",
              recovery: "Turn it off.", conflicts: [], symptomID: nil),
        Tweak(id: "AirDropDisableTimeLimit", title: "AirDrop \"Everyone\" never times out", detail: "Everyone mode stays on instead of reverting after 10 minutes.",
              category: .system, target: key(airdrop, "AirDropDisableTimeLimit"), kind: .toggle, onValue: .bool(true), tier: .caution,
              minOS: nil, maxOS: nil, respring: false, verification: "Read back from sharingd preferences",
              recovery: "Turn it off. Be careful on public networks.", conflicts: [], symptomID: nil),
    ]

    static func tweak(_ id: String) -> Tweak? { all.first { $0.id == id } }
}

/// A named set of tweaks to turn on together.
struct Preset: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let tweakIDs: [String]
    var tweaks: [Tweak] { tweakIDs.compactMap(TweakCatalog.tweak) }
    var tier: Tier { tweaks.map(\.tier).max() ?? .reversible }

    static let all: [Preset] = [
        Preset(id: "quiet", title: "Quiet Home", detail: "Fewer interruptions: no low-battery alerts, no breadcrumb.",
               tweakIDs: ["SBHideLowPowerAlerts", "SBNeverBreadcrumb"]),
        Preset(id: "recording", title: "Screen recording", detail: "Touch dots on, for tutorials. Turn it off afterwards.",
               tweakIDs: ["BKDigitizerVisualizeTouches"]),
        Preset(id: "desk", title: "Desk mode", detail: "Screen stays awake on the charger; Lock Screen stays on longer.",
               tweakIDs: ["SBDontDimOrLockOnAC", "SBMinimumLockscreenIdleTime"]),
    ]
}
