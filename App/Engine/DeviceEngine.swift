import Foundation
import UIKit

/// Where a fact came from (§3.3). Every value Assay shows carries one.
enum Evidence: Equatable, Hashable {
    case observed            // read directly from the device or OS
    case inferred(Int)       // our reasoning, with confidence %
    case unknown             // iOS doesn't expose it
}

struct Fact: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: String
    let evidence: Evidence
    var source: String = ""
}

/// A point-in-time view of the device. Used by Home, Device check and the passport.
struct DeviceSnapshot: Equatable {
    var name: String
    var model: String
    var osVersion: String
    var build: String?
    var connected: Bool
    var isDemo: Bool
    var facts: [Fact]
    var healthScore: Int?          // nil until a device check has run
    var backup: BackupStatus?
    var takenAt = Date()
}

struct BackupStatus: Equatable {
    enum Phase: Equatable { case none, running(Double), paused, done(Date) }
    var phase: Phase
    var reusedBytes: Int64 = 0
    var totalBytes: Int64 = 0
}

/// Engines do the device work. The UI never talks to transport directly.
protocol DeviceEngine {
    var mode: EngineMode { get }
    var displayName: String { get }
    /// Whether the engine can currently reach the device for writes/backups.
    func availability() async -> EngineAvailability
    func snapshot() async -> DeviceSnapshot
}

enum EngineAvailability: Equatable {
    case ready
    case needsSetup(String)    // plain-English next step
    case unavailable(String)
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
        case .nominal: "Nominal"; case .fair: "Fair"; case .serious: "Serious"; case .critical: "Critical"; @unknown default: "Unknown"
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
