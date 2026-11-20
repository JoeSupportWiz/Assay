import Foundation
import Observation

// MARK: - Values and targets

/// A preference value as Assay reads and writes it.
enum PlistValue: Codable, Hashable {
    case bool(Bool), int(Int), double(Double), string(String)
    var display: String {
        switch self {
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return String(format: "%g", d)
        case .string(let s): return "\"\(s)\""
        }
    }
}

/// Where a value lives: a preferences domain and key.
struct PrefKey: Codable, Hashable {
    var domain: String
    var key: String
}

/// Safety tier (spec §3.3). Ordered: reversible < caution < experimental.
enum Tier: String, Codable, CaseIterable, Comparable {
    case reversible, caution, experimental
    var rank: Int {
        switch self { case .reversible: return 0; case .caution: return 1; case .experimental: return 2 }
    }
    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rank < rhs.rank }
    var title: String { rawValue.capitalized }
    var tag: TagStyle {
        switch self { case .reversible: return .reversible; case .caution: return .caution; case .experimental: return .experimental }
    }
    var explanation: String {
        switch self {
        case .reversible: return "The old value is saved first and read back after. One tap undoes it."
        case .caution: return "Version-sensitive. Assay checks first and keeps recovery notes."
        case .experimental: return "Unsupported or untested here. Opt-in only, never applied automatically."
        }
    }
}

// MARK: - Changes and plans

/// One value change. `after == nil` removes the key so iOS falls back to its default.
struct Change: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var target: PrefKey
    var before: PlistValue?
    var after: PlistValue?
    var tier: Tier
    /// True once the current value has been read (so `before` is trustworthy and undo is possible).
    var beforeKnown = false

    var inverted: Change {
        Change(label: "Undo: " + label, target: target, before: after, after: before, tier: tier, beforeKnown: true)
    }
}

/// What will happen, before it happens.
struct OperationPlan: Identifiable, Hashable {
    enum Kind: String, Codable { case fix, tweak, undo, scene, restoreAll }
    var id = UUID()
    var title: String
    var kind: Kind
    var changes: [Change]
    var needsRespring = false
    var userCheck: String? = nil
    /// Receipts this plan reverses (undo / restore all).
    var undoOf: [Int] = []
    var undoEngine: EngineMode? = nil
    /// Set only on the transient copy submitted after the owner reviews this plan.
    var riskAcknowledged = false
    var tier: Tier { changes.map(\.tier).max() ?? .reversible }
}

// MARK: - Receipts

/// The record left behind by every operation, including dry runs.
struct Receipt: Identifiable, Codable, Hashable {
    enum Outcome: String, Codable {
        case verified, unverified, failed, simulated, skipped

        var potentiallyApplied: Bool { self == .verified || self == .unverified }
        var tag: (TagStyle, String) {
            switch self {
            case .verified: (.reversible, "Read back OK")
            case .unverified: (.caution, "Unverified")
            case .failed: (.experimental, "Failed")
            case .simulated: (.unknown, "Dry run")
            case .skipped: (.neutral, "Not attempted")
            }
        }
    }
    struct Item: Codable, Hashable {
        var change: Change
        var outcome: Outcome
        var note: String?
    }
    enum Status { case complete, partial, failed, simulated, rolledBack }

    var id: Int
    var date: Date
    var title: String
    var kind: OperationPlan.Kind
    var engine: EngineMode
    var dryRun: Bool
    var items: [Item]
    var rolledBack = false
    var userConfirmed: Bool? = nil

    var status: Status {
        if dryRun { return items.allSatisfy({ $0.outcome == .simulated }) ? .simulated : .failed }
        if rolledBack { return .rolledBack }
        if items.isEmpty { return .failed }
        if items.allSatisfy({ $0.outcome == .verified }) { return .complete }
        return items.contains(where: { $0.outcome.potentiallyApplied }) ? .partial : .failed
    }

    var undoable: Bool {
        !dryRun && !rolledBack && kind != .undo && kind != .restoreAll
            && !items.isEmpty && items.allSatisfy { $0.outcome == .verified && $0.change.beforeKnown }
    }

    var reversibleCount: Int { items.filter { $0.outcome == .verified && $0.change.beforeKnown }.count }

    var statusTag: (TagStyle, String) {
        switch status {
        case .complete: return (.reversible, "Verified")
        case .partial: return (.caution, "Partial")
        case .failed: return (.experimental, "Failed")
        case .simulated: return (.unknown, "Dry run")
        case .rolledBack: return (.neutral, "Rolled back")
        }
    }
}

/// Persists receipts on device (Application Support, complete file protection). Never synced.
@Observable
final class ReceiptStore {
    private(set) var receipts: [Receipt] = []
    enum StorageIssue: Equatable {
        case damaged, unavailable, changed, saveFailed
        var message: String {
            switch self {
            case .damaged: "Assay couldn’t decode the existing history. Its file has been kept unchanged. No receipts can be saved until you choose how to continue."
            case .unavailable: "Assay can’t read the history file. Unlock the device and try reading it again. No new history will be created."
            case .changed: "The history file changed since it was read. Read it again before continuing."
            case .saveFailed: "Assay couldn’t save this history update. Read history again before continuing."
            }
        }
    }
    private(set) var storageIssue: StorageIssue?
    private(set) var lastBackupName: String?
    private let persist: Bool
    private let fileURL: URL
    @ObservationIgnored private var loadedBytes: Data?

    init(persist: Bool = true, seed: [Receipt] = [], fileURL: URL? = nil) {
        self.persist = persist
        self.fileURL = fileURL ?? Self.url
        if persist { reload() } else { receipts = seed }
    }

    var nextID: Int { (receipts.map(\.id).max() ?? 200) + 1 }
    var changeCount: Int { verifiedChangeCount(engine: nil) }
    func verifiedChangeCount(engine: EngineMode?) -> Int {
        receipts.filter { !$0.dryRun && !$0.rolledBack && (engine == nil || $0.engine == engine) }
            .reduce(0) { $0 + $1.items.filter { $0.outcome == .verified }.count }
    }

    func add(_ r: Receipt) { save([r] + receipts) }

    func acknowledgeUndo(_ plan: OperationPlan, result: Receipt) {
        guard !plan.undoOf.isEmpty, plan.undoEngine == result.engine, !result.dryRun, result.status == .complete,
              result.kind == plan.kind, result.items.count == plan.changes.count,
              zip(result.items,plan.changes).allSatisfy({ item, change in item.outcome == .verified && item.change.target == change.target && item.change.after == change.after }) else { return }
        var updated = receipts
        for i in receipts.indices where plan.undoOf.contains(receipts[i].id) && receipts[i].engine == result.engine && receipts[i].undoable { updated[i].rolledBack = true }
        save(updated)
    }

    func confirm(_ id: Int, ok: Bool) {
        if let i = receipts.firstIndex(where: { $0.id == id }) {
            var updated = receipts; updated[i].userConfirmed = ok; save(updated)
        }
    }

    func undoPlan(for r: Receipt, engine: EngineMode) -> OperationPlan? {
        guard storageIssue == nil, r.engine == engine, r.undoable, let position = receipts.firstIndex(where: { $0.id == r.id && $0.engine == engine }), receipts[position] == r else { return nil }
        let keys = Set(r.items.map(\.change.target))
        guard !receipts.prefix(position).contains(where: { other in
            other.engine == engine && !other.dryRun && !other.rolledBack && other.kind != .undo && other.kind != .restoreAll && other.items.contains { keys.contains($0.change.target) && $0.outcome.potentiallyApplied }
        }) else { return nil }
        let changes = r.items.reversed().map { $0.change.inverted }
        return OperationPlan(title: "Undo #\(r.id) · \(r.title)", kind: .undo, changes: changes,
                             needsRespring: true, userCheck: "Is everything back to how it was?", undoOf: [r.id], undoEngine: engine)
    }

    /// Reverse every undoable receipt, newest first; for keys touched more than once the oldest "before" wins.
    func restoreAllPlan(engine: EngineMode) -> OperationPlan? {
        guard storageIssue == nil else { return nil }
        let relevant = receipts.filter { $0.engine == engine && !$0.dryRun && !$0.rolledBack && $0.kind != .undo && $0.kind != .restoreAll }
        guard !relevant.contains(where: { !$0.undoable && $0.items.contains { $0.outcome == .verified || $0.outcome == .unverified } }) else {return nil}
        let targets = relevant.filter(\.undoable).sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
        guard !targets.isEmpty else { return nil }
        var order: [PrefKey] = []
        var byKey: [PrefKey: Change] = [:]
        for r in targets {
            for item in r.items.reversed() {
                var inv = item.change.inverted
                if let newest = byKey[inv.target] {
                    guard newest.after == inv.before else { return nil } // discontinuous history
                    inv.before = newest.before
                } else { order.append(inv.target) }
                byKey[inv.target] = inv
            }
        }
        let changes = order.compactMap { byKey[$0] }
        return OperationPlan(title: "Restore to before Assay", kind: .restoreAll, changes: changes,
                             needsRespring: true, userCheck: "Is your iPhone back to how it was before Assay?",
                             undoOf: targets.map(\.id), undoEngine: engine)
    }

    var needsYouCount: Int {
        receipts.filter { !$0.dryRun && !$0.rolledBack }.reduce(0) { acc, r in
            acc + r.items.filter { !$0.change.beforeKnown && $0.outcome.potentiallyApplied }.count
        }
    }

    // MARK: Storage

    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Assay", isDirectory: true).appendingPathComponent("receipts.json")
    }

    /// Absence is the only read error that permits initial creation. A directory, protected
    /// file, or other I/O error is *not* evidence that history is empty or damaged.
    private func sourceBytes() throws -> Data? {
        // Inspect the entry itself first: a dangling symlink is not a missing history.
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw CocoaError(.fileReadUnknown) }
        return try Data(contentsOf: fileURL)
    }

    func reload() {
        guard persist else { return }
        do { loadedBytes = try sourceBytes() }
        catch { storageIssue = .unavailable; return }
        guard let loadedBytes else { receipts = []; storageIssue = nil; return }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        do { receipts = try decoder.decode([Receipt].self, from: loadedBytes); storageIssue = nil }
        catch { receipts = []; storageIssue = .damaged }
    }

    private func sourceIsUnchanged() -> Bool {
        do { if try sourceBytes() == loadedBytes { return true }; storageIssue = .changed }
        catch { storageIssue = .unavailable }
        return false
    }

    /// Only the explicit History confirmation calls this. A failed backup never unlocks saves.
    func startNewHistory() {
        guard storageIssue == .damaged, let bytes = loadedBytes, sourceIsUnchanged() else { return }
        let base = fileURL.deletingPathExtension().lastPathComponent
        let directory = fileURL.deletingLastPathComponent()
        var index = 1
        do {
            while true {
                let backup = directory.appendingPathComponent("\(base).damaged-\(index).json")
                do { try bytes.write(to: backup, options: [.withoutOverwriting, .completeFileProtection]) }
                catch let error as CocoaError where error.code == .fileWriteFileExists { index += 1; continue }
                lastBackupName = backup.lastPathComponent
                break
            }
            guard sourceIsUnchanged() else { return }
            let empty = Data("[]".utf8)
            try empty.write(to: fileURL, options: [.atomic, .completeFileProtection])
            receipts = []; loadedBytes = empty; storageIssue = nil
        } catch { storageIssue = .saveFailed }
    }

    private func save(_ updated: [Receipt]) {
        guard storageIssue == nil else { return }
        guard persist else { receipts = updated; return }
        guard sourceIsUnchanged() else { return }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(updated)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let options: Data.WritingOptions = loadedBytes == nil ? [.withoutOverwriting, .completeFileProtection] : [.atomic, .completeFileProtection]
            try data.write(to: fileURL, options: options)
            receipts = updated; loadedBytes = data
        } catch { storageIssue = .saveFailed }
    }

    /// Sample history for the Demo engine (screenshots and first look). Every item is engine = .demo.
    static func demoSeed() -> [Receipt] {
        let now = Date()
        func ch(_ label: String, _ domain: String, _ key: String, _ before: PlistValue?, _ after: PlistValue?, _ tier: Tier, known: Bool = true) -> Change {
            Change(label: label, target: PrefKey(domain: domain, key: key), before: before, after: after, tier: tier, beforeKnown: known)
        }
        let sb = "com.apple.springboard", bk = "com.apple.backboardd"
        return [
            Receipt(id: 213, date: now.addingTimeInterval(-9 * 60), title: "Fix: white dots on touch", kind: .fix, engine: .demo, dryRun: false,
                    items: [.init(change: ch("Stop showing touches", bk, "BKDigitizerVisualizeTouches", .bool(true), nil, .reversible), outcome: .verified, note: nil)],
                    userConfirmed: true),
            Receipt(id: 212, date: now.addingTimeInterval(-42 * 60), title: "3 tweaks · Quiet Home", kind: .tweak, engine: .demo, dryRun: false,
                    items: [.init(change: ch("Hide low-battery alerts", sb, "SBHideLowPowerAlerts", nil, .bool(true), .reversible), outcome: .verified, note: nil),
                            .init(change: ch("Hide breadcrumb", sb, "SBNeverBreadcrumb", nil, .bool(true), .reversible), outcome: .verified, note: nil),
                            .init(change: ch("Lock Screen footnote", sb, "LockScreenFootnote", nil, .string("Joe's iPhone"), .caution), outcome: .verified, note: nil)]),
            Receipt(id: 211, date: now.addingTimeInterval(-27 * 3600), title: "Restore after update", kind: .tweak, engine: .demo, dryRun: false,
                    items: [.init(change: ch("Status bar archive", sb, "SBStatusBarOverrides", nil, .string("reset"), .caution, known: false), outcome: .unverified,
                                  note: "1 key couldn't be captured, so it can't be undone")]),
            Receipt(id: 210, date: now.addingTimeInterval(-28 * 3600), title: "Fix: authentication line", kind: .fix, engine: .demo, dryRun: true,
                    items: [.init(change: ch("Turn off authentication line", sb, "SBShowAuthenticationEngineeringUI", .bool(true), nil, .reversible), outcome: .simulated, note: nil)]),
        ]
    }
}
