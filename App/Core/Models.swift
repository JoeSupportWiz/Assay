import Foundation

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
