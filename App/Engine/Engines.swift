import Foundation
import UIKit

/// Lets every screen run with no device or pairing. Everything it returns is labelled Demo in the UI.
struct DemoEngine: DeviceEngine {
    let mode = EngineMode.demo
    let displayName = "Demo device"
    func availability() async -> EngineAvailability { .ready }
    func snapshot() async -> DeviceSnapshot {
        DeviceSnapshot(name: "Demo iPhone", model: "iPhone 16 Pro", osVersion: "26.1", build: "23B85",
                       connected: true, isDemo: true,
                       facts: [
                        Fact(label: "Model", value: "iPhone17,1", evidence: .observed, source: "Demo"),
                        Fact(label: "iOS", value: "26.1 (23B85)", evidence: .observed, source: "Demo"),
                        Fact(label: "Battery health", value: "94%", evidence: .observed, source: "Demo"),
                        Fact(label: "Status bar override", value: "Present", evidence: .inferred(82), source: "Demo"),
                        Fact(label: "Current wallpaper", value: "Not shared with apps", evidence: .unknown, source: "iOS privacy"),
                       ],
                       healthScore: 94,
                       backup: BackupStatus(phase: .running(0.62), reusedBytes: 2_300_000_000, totalBytes: 6_600_000_000))
    }
}

/// iPhone-only engine: everything runs on this phone through Assay's own loopback.
/// Phase 0 reports real public-API facts; device writes arrive with the tunnel (roadmap 3.2–3.4).
struct OnDeviceEngine: DeviceEngine {
    let mode = EngineMode.iphone
    let displayName = "This iPhone"
    func availability() async -> EngineAvailability {
        .needsSetup("Import a pairing file and turn on the Assay loopback to make changes.")
    }
    func snapshot() async -> DeviceSnapshot {
        return await MainActor.run {
            DeviceSnapshot(name: UIDevice.current.name, model: LocalFacts.modelIdentifier(), osVersion: UIDevice.current.systemVersion,
                           build: nil, connected: false, isDemo: false, facts: LocalFacts.collect(), healthScore: nil, backup: nil)
        }
    }
}

/// Mac companion engine: heavy work runs on Assay for Mac over USB; the phone shows status.
/// Phase 0 shows local facts and a "find your Mac" state (roadmap 3.5).
struct MacCompanionEngine: DeviceEngine {
    let mode = EngineMode.mac
    let displayName = "Assay for Mac"
    func availability() async -> EngineAvailability {
        .needsSetup("Open Assay for Mac on the same network, then approve this iPhone.")
    }
    func snapshot() async -> DeviceSnapshot {
        return await MainActor.run {
            DeviceSnapshot(name: UIDevice.current.name, model: LocalFacts.modelIdentifier(), osVersion: UIDevice.current.systemVersion,
                           build: nil, connected: false, isDemo: false, facts: LocalFacts.collect(), healthScore: nil, backup: nil)
        }
    }
}
