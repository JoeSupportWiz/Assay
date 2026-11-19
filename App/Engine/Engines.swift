import Foundation
import UIKit

/// In-memory preference store the Demo engine writes to. Shared so state survives engine rebuilds.
actor DemoPrefs {
    static let shared = DemoPrefs()
    /// Starts with the problems seen in real GoldenNugget logs, so Diagnose has something to find.
    private var values: [PrefKey: PlistValue] = [
        PrefKey(domain: Knowledge.sb, key: "SBShowStatusBarOverridesForRecording"): .bool(true),
        PrefKey(domain: Knowledge.sb, key: "SBShowAuthenticationEngineeringUI"): .bool(true),
        PrefKey(domain: Knowledge.sb, key: "SBHideLowPowerAlerts"): .bool(true),
    ]
    func get(_ k: PrefKey) -> PlistValue? { values[k] }
    func set(_ k: PrefKey, _ v: PlistValue?) { values[k] = v }
}

/// Lets every screen run with no device or pairing. Everything it returns is labelled Demo in the UI.
struct DemoEngine: DeviceEngine {
    let mode = EngineMode.demo
    let displayName = "Demo device"
    let canRead = true
    func availability() async -> EngineAvailability { .ready }
    func read(_ key: PrefKey) async -> PlistValue? { await DemoPrefs.shared.get(key) }
    func write(_ key: PrefKey, _ value: PlistValue?) async -> WriteResult {
        try? await Task.sleep(for: .milliseconds(650))
        await DemoPrefs.shared.set(key, value)
        let back = await DemoPrefs.shared.get(key)
        return WriteResult(outcome: back == value ? .verified : .failed, note: back == value ? "Read back OK" : "Read-back mismatch")
    }
    func check() async -> [Finding] {
        let snap = await snapshot()
        return await standardCheck(snapshot: snap)
    }
    func snapshot() async -> DeviceSnapshot {
        let override = await DemoPrefs.shared.get(PrefKey(domain: Knowledge.sb, key: "SBShowStatusBarOverridesForRecording")) == .bool(true)
        return DeviceSnapshot(name: "Demo iPhone", model: "iPhone 16 Pro", osVersion: "26.1", build: "23B85",
                       connected: true, isDemo: true,
                       facts: [
                        Fact(label: "Model", value: "iPhone17,1", evidence: .observed, source: "Demo"),
                        Fact(label: "iOS", value: "26.1 (23B85)", evidence: .observed, source: "Demo"),
                        Fact(label: "Battery health", value: "94%", evidence: .observed, source: "Demo"),
                        Fact(label: "Status bar override", value: override ? "Present" : "None", evidence: override ? .inferred(82) : .observed, source: "Demo"),
                        Fact(label: "Current wallpaper", value: "Not shared with apps", evidence: .unknown, source: "iOS privacy"),
                       ],
                       healthScore: override ? 94 : 100,
                       backup: BackupStatus(phase: .running(0.62), reusedBytes: 2_300_000_000, totalBytes: 6_600_000_000))
    }
}

/// iPhone-only engine: everything runs on this phone through Assay's own loopback.
/// Until the tunnel lands (roadmap 3.2–3.4) it reports real public-API facts and can't read or write preferences.
struct OnDeviceEngine: DeviceEngine {
    let mode = EngineMode.iphone
    let displayName = "This iPhone"
    let canRead = false
    func availability() async -> EngineAvailability {
        .needsSetup("Import a pairing file and turn on the Assay loopback to make changes.")
    }
    func read(_ key: PrefKey) async -> PlistValue? { nil }
    func write(_ key: PrefKey, _ value: PlistValue?) async -> WriteResult {
        WriteResult(outcome: .failed, note: "Engine not set up yet — nothing was written")
    }
    func check() async -> [Finding] { await standardCheck(snapshot: await snapshot()) }
    func snapshot() async -> DeviceSnapshot {
        await MainActor.run {
            DeviceSnapshot(name: UIDevice.current.name, model: LocalFacts.modelIdentifier(), osVersion: UIDevice.current.systemVersion,
                           build: nil, connected: false, isDemo: false, facts: LocalFacts.collect(), healthScore: nil, backup: nil)
        }
    }
}

/// Mac companion engine: heavy work runs on Assay for Mac over USB; the phone shows status.
/// Until the companion lands (roadmap 3.5) it shows local facts and a "find your Mac" state.
struct MacCompanionEngine: DeviceEngine {
    let mode = EngineMode.mac
    let displayName = "Assay for Mac"
    let canRead = false
    func availability() async -> EngineAvailability {
        .needsSetup("Open Assay for Mac on the same network, then approve this iPhone.")
    }
    func read(_ key: PrefKey) async -> PlistValue? { nil }
    func write(_ key: PrefKey, _ value: PlistValue?) async -> WriteResult {
        WriteResult(outcome: .failed, note: "Mac not connected — nothing was written")
    }
    func check() async -> [Finding] { await standardCheck(snapshot: await snapshot()) }
    func snapshot() async -> DeviceSnapshot {
        await MainActor.run {
            DeviceSnapshot(name: UIDevice.current.name, model: LocalFacts.modelIdentifier(), osVersion: UIDevice.current.systemVersion,
                           build: nil, connected: false, isDemo: false, facts: LocalFacts.collect(), healthScore: nil, backup: nil)
        }
    }
}
