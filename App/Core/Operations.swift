import Foundation

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
    var tier: Tier { changes.map(\.tier).max() ?? .reversible }
}

// MARK: - Receipts

/// The record left behind by every operation, including dry runs.
struct Receipt: Identifiable, Codable, Hashable {
    enum Outcome: String, Codable { case verified, unverified, failed, simulated }
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
        if dryRun { return .simulated }
        if rolledBack { return .rolledBack }
        let failed = items.filter { $0.outcome == .failed }.count
        if !items.isEmpty && failed == items.count { return .failed }
        if failed > 0 || items.contains(where: { $0.outcome == .unverified }) { return .partial }
        return .complete
    }

    var undoable: Bool {
        !dryRun && !rolledBack && kind != .undo && kind != .restoreAll
            && items.contains(where: { $0.outcome != .failed && $0.change.beforeKnown })
    }

    var reversibleCount: Int { items.filter { $0.outcome != .failed && $0.change.beforeKnown }.count }

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
    private let persist: Bool

    init(persist: Bool = true, seed: [Receipt] = []) {
        self.persist = persist
        receipts = persist ? Self.load() : seed
    }

    var nextID: Int { (receipts.map(\.id).max() ?? 200) + 1 }
    var changeCount: Int { verifiedChangeCount(engine: nil) }
    func verifiedChangeCount(engine: EngineMode?) -> Int {
        receipts.filter { !$0.dryRun && !$0.rolledBack && (engine == nil || $0.engine == engine) }
            .reduce(0) { $0 + $1.items.filter { $0.outcome == .verified }.count }
    }

    func add(_ r: Receipt) { receipts.insert(r, at: 0); save() }

    func markRolledBack(_ ids: [Int]) {
        for id in ids { if let i = receipts.firstIndex(where: { $0.id == id }) { receipts[i].rolledBack = true } }
        save()
    }

    func confirm(_ id: Int, ok: Bool) {
        if let i = receipts.firstIndex(where: { $0.id == id }) { receipts[i].userConfirmed = ok; save() }
    }

    func undoPlan(for r: Receipt) -> OperationPlan {
        let changes = r.items.filter { $0.outcome != .failed && $0.change.beforeKnown }.map { $0.change.inverted }
        return OperationPlan(title: "Undo #\(r.id) · \(r.title)", kind: .undo, changes: changes,
                             needsRespring: true, userCheck: "Is everything back to how it was?", undoOf: [r.id])
    }

    /// Reverse every undoable receipt, newest first; for keys touched more than once the oldest "before" wins.
    func restoreAllPlan() -> OperationPlan? {
        let targets = receipts.filter(\.undoable).sorted { $0.date > $1.date }
        guard !targets.isEmpty else { return nil }
        var order: [PrefKey] = []
        var byKey: [PrefKey: Change] = [:]
        for r in targets {
            for item in r.items where item.outcome != .failed && item.change.beforeKnown {
                let inv = item.change.inverted
                if byKey[inv.target] == nil { order.append(inv.target) }
                byKey[inv.target] = inv
            }
        }
        let changes = order.compactMap { byKey[$0] }
        return OperationPlan(title: "Restore to before Assay", kind: .restoreAll, changes: changes,
                             needsRespring: true, userCheck: "Is your iPhone back to how it was before Assay?",
                             undoOf: targets.map(\.id))
    }

    var needsYouCount: Int {
        receipts.filter { !$0.dryRun && !$0.rolledBack }.reduce(0) { acc, r in
            acc + r.items.filter { !$0.change.beforeKnown && $0.outcome != .failed }.count
        }
    }

    // MARK: Storage

    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Assay", isDirectory: true).appendingPathComponent("receipts.json")
    }

    private static func load() -> [Receipt] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([Receipt].self, from: data)) ?? []
    }

    private func save() {
        guard persist else { return }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(receipts) else { return }
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.url, options: [.atomic, .completeFileProtection])
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
