import Foundation
import UIKit

/// Result of one write, read back.
struct WriteResult {
    var outcome: Receipt.Outcome
    var note: String?
}

/// Engines do the device work. The UI never talks to transport directly.
protocol DeviceEngine {
    var mode: EngineMode { get }
    var displayName: String { get }
    /// Whether the engine can currently reach the device for writes/backups.
    func availability() async -> EngineAvailability
    func snapshot() async -> DeviceSnapshot
    /// Read a preference. `nil` = key absent (or unreadable — see `canRead`).
    func read(_ key: PrefKey) async -> PlistValue?
    var canRead: Bool { get }
    /// Write (or remove, when `value == nil`) and read back.
    func write(_ key: PrefKey, _ value: PlistValue?) async -> WriteResult
    /// Run checks and return findings. Read-only.
    func check() async -> [Finding]
}

extension DeviceEngine {
    /// Shared check logic: snapshot facts + every known culprit read from the device.
    func standardCheck(snapshot: DeviceSnapshot) async -> [Finding] {
        var findings: [Finding] = []
        for s in Knowledge.symptoms {
            guard let key = s.culprit else { continue }
            if canRead {
                let v = await read(key)
                if let v, v == s.culpritValue {
                    findings.append(Finding(id: s.id, title: s.title, reason: s.cause, severity: .attention,
                        evidence: [Fact(label: "\(key.domain) › \(key.key)", value: v.display, evidence: .observed, source: displayName)],
                        fix: s.plan(current: v), symptomID: s.id, confidence: nil))
                }
            }
        }
        if !canRead {
            findings.append(Finding(id: "prefs-unreadable", title: "System preferences not readable yet",
                reason: "This engine can't read SpringBoard preferences until setup is finished, so tweak-related problems can't be ruled out.",
                severity: .info, evidence: [Fact(label: "Preference access", value: "Needs engine setup", evidence: .unknown, source: displayName)],
                fix: nil, symptomID: nil, confidence: nil))
        }
        for f in snapshot.facts {
            if f.label == "Thermal state", f.value == "Serious" || f.value == "Critical" {
                findings.append(Finding(id: "thermal", title: "iPhone is running hot", reason: "Thermal state is \(f.value). Long backups may slow or pause.",
                    severity: .attention, evidence: [f], fix: nil, symptomID: nil, confidence: nil))
            }
            if f.label == "Low Power Mode", f.value == "On" {
                findings.append(Finding(id: "lowpower", title: "Low Power Mode is on", reason: "iOS throttles background work and networking, which slows on-device backups.",
                    severity: .info, evidence: [f], fix: nil, symptomID: nil, confidence: nil))
            }
        }
        return findings.sorted { $0.severity > $1.severity }
    }
}

enum EngineAvailability: Equatable {
    case ready
    case needsSetup(String)    // plain-English next step
    case unavailable(String)
}

/// Runs an OperationPlan through any engine: snapshot → write → read back → receipt.
struct OperationRunner {
    enum Stage: Equatable { case snapshot, writing(Int, Int), verifying, done }

    static func run(_ plan: OperationPlan, engine: any DeviceEngine, dryRun: Bool, receiptID: Int,
                    progress: @escaping @MainActor (Stage) -> Void) async -> Receipt {
        await progress(.snapshot)
        // Re-read every "before" right now so undo reflects reality, not the plan.
        var changes = plan.changes
        if engine.canRead {
            for i in changes.indices {
                changes[i].before = await engine.read(changes[i].target)
                changes[i].beforeKnown = true
            }
        }
        try? await Task.sleep(for: .milliseconds(500))
        var items: [Receipt.Item] = []
        for (i, c) in changes.enumerated() {
            await progress(.writing(i + 1, changes.count))
            if dryRun {
                try? await Task.sleep(for: .milliseconds(450))
                items.append(.init(change: c, outcome: .simulated, note: "Nothing was written"))
            } else {
                let r = await engine.write(c.target, c.after)
                items.append(.init(change: c, outcome: r.outcome, note: r.note))
            }
        }
        await progress(.verifying)
        try? await Task.sleep(for: .milliseconds(500))
        await progress(.done)
        return Receipt(id: receiptID, date: Date(), title: plan.title, kind: plan.kind, engine: engine.mode, dryRun: dryRun, items: items)
    }
}

// MARK: - On-device facts any engine can use (public APIs only; always Observed)

@MainActor
enum LocalFacts {
    static func collect() -> [Fact] {
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        var f: [Fact] = []
        f.append(Fact(label: "Model", value: modelIdentifier(), evidence: .observed, source: "uname()"))
        f.append(Fact(label: "iOS", value: d.systemVersion, evidence: .observed, source: "UIDevice"))
        if d.batteryLevel >= 0 {
            f.append(Fact(label: "Battery", value: "\(Int(d.batteryLevel * 100))%", evidence: .observed, source: "UIDevice"))
        } else {
            f.append(Fact(label: "Battery", value: "Not reported", evidence: .unknown, source: "Simulator or unavailable"))
        }
        f.append(Fact(label: "Low Power Mode", value: ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off", evidence: .observed, source: "ProcessInfo"))
        f.append(Fact(label: "Thermal state", value: thermal(), evidence: .observed, source: "ProcessInfo"))
        if let free = freeStorage() {
            f.append(Fact(label: "Free storage", value: ByteCountFormatter.string(fromByteCount: free, countStyle: .file), evidence: .observed, source: "URLResourceValues"))
        }
        f.append(Fact(label: "Uptime", value: uptime(), evidence: .observed, source: "ProcessInfo"))
        f.append(Fact(label: "Current wallpaper", value: "Not shared with apps", evidence: .unknown, source: "iOS privacy"))
        return f
    }

    static func modelIdentifier() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim + " (Simulator)" }
        var s = utsname(); uname(&s)
        return withUnsafeBytes(of: &s.machine) { buf in String(decoding: buf.prefix { $0 != 0 }, as: UTF8.self) }
    }

    private static func thermal() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"; case .fair: return "Fair"; case .serious: return "Serious"; case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private static func freeStorage() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        return (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
    }

    private static func uptime() -> String {
        let f = DateComponentsFormatter(); f.allowedUnits = [.day, .hour, .minute]; f.unitsStyle = .abbreviated
        return f.string(from: ProcessInfo.processInfo.systemUptime) ?? "—"
    }
}
