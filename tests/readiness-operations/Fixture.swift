import Foundation

// App shell / SwiftUI-only types. Store, plan, policy, runner and receipts are production.
enum EngineMode: String, Codable, CaseIterable { case demo, mac, iphone }
enum TagStyle { case reversible, caution, experimental, neutral, unknown }

private actor Probe: DeviceEngine {
    let mode: EngineMode
    let displayName = "Fixture"
    let canRead = true
    let canWritePreferences: Bool
    let outcomes: [Receipt.Outcome]
    private(set) var writes: [PrefKey] = []

    init(_ mode: EngineMode, canWrite: Bool, returning outcomes: [Receipt.Outcome] = []) {
        self.mode = mode; canWritePreferences = canWrite; self.outcomes = outcomes
    }
    func availability() async -> EngineAvailability { .ready }
    func snapshot() async -> DeviceSnapshot { fatalError("No device snapshots in fixture") }
    func check() async -> [Finding] { [] }
    func read(_ key: PrefKey) async -> PlistValue? { .int(0) }
    func write(_ key: PrefKey, _ value: PlistValue?) async -> WriteResult {
        let i = writes.count; writes.append(key)
        return WriteResult(outcome: i < outcomes.count ? outcomes[i] : .verified, note: nil)
    }
}

@main enum ReadinessFixture {
    static func plan(_ tier: Tier) -> OperationPlan {
        .init(title: "Fixture", kind: .tweak, changes: (1...3).map { i in
            .init(label: "Key \(i)", target: .init(domain: "fixture", key: "\(i)"), before: nil, after: .int(i), tier: i == 2 ? tier : .reversible)
        })
    }
    static func receipt(_ id: Int) -> Receipt {
        .init(id: id, date: Date(timeIntervalSince1970: Double(id)), title: "Fixture", kind: .tweak, engine: .demo, dryRun: false,
              items: plan(.reversible).changes.map { .init(change: $0, outcome: .verified) })
    }

    static func storage(in root: URL) throws {
        let fm = FileManager.default
        let url = root.appendingPathComponent("receipts.json")
        func store() -> ReceiptStore { ReceiptStore(fileURL: url) }
        func bytes(_ file: URL) -> Data { try! Data(contentsOf: file) }
        let first = store(); precondition(first.storageIssue == nil && !fm.fileExists(atPath: url.path))
        first.add(receipt(first.nextID)); first.add(receipt(first.nextID))
        first.confirm(201, ok: true)
        let restarted = store()
        precondition(restarted.receipts.map(\.id) == [202, 201] && restarted.receipts.last?.userConfirmed == true)
        restarted.add(receipt(restarted.nextID)); precondition(store().receipts.map(\.id) == [203, 202, 201])
        print("PASS normal append, confirm, restart and append")

        let bad = Data([0x5b, 0xff, 0x7b])
        try bad.write(to: url)
        restarted.add(receipt(204)); precondition(restarted.storageIssue == .changed && bytes(url) == bad)
        let blocked = store(); precondition(blocked.storageIssue == .damaged)
        blocked.add(receipt(204)); blocked.confirm(204, ok: true)
        precondition(bytes(url) == bad && blocked.receipts.isEmpty && store().storageIssue == .damaged)
        let previous = root.appendingPathComponent("receipts.damaged-1.json")
        let keep = Data("previous backup".utf8); try keep.write(to: previous)
        blocked.startNewHistory()
        let backup = root.appendingPathComponent("receipts.damaged-2.json")
        precondition(blocked.storageIssue == nil && blocked.lastBackupName == backup.lastPathComponent)
        precondition(bytes(previous) == keep && bytes(backup) == bad && store().storageIssue == nil && store().receipts.isEmpty)
        let fresh = receipt(201); blocked.add(fresh)
        precondition(store().receipts == [fresh] && bytes(backup) == bad)
        print("PASS damaged bytes preserved, explicit recovery, collision and retained backup")

        try bad.write(to: url); let stale = store()
        let fixed = Data("[]".utf8); try fixed.write(to: url)
        stale.startNewHistory(); precondition(stale.storageIssue == .changed && bytes(url) == fixed)
        stale.reload(); precondition(stale.storageIssue == nil)
        // A directory at the source is deterministically unreadable as a file, even when run as root.
        try fm.removeItem(at: url); try fm.createDirectory(at: url, withIntermediateDirectories: false)
        let names = try fm.contentsOfDirectory(atPath: root.path).sorted()
        let unavailable = store(); precondition(unavailable.storageIssue == .unavailable)
        unavailable.startNewHistory(); unavailable.add(receipt(1)); stale.add(receipt(2))
        let after = try fm.contentsOfDirectory(atPath: root.path).sorted()
        precondition(unavailable.storageIssue == .unavailable && stale.storageIssue == .unavailable && names == after)
        try fm.removeItem(at: url); try fixed.write(to: url); unavailable.reload()
        precondition(unavailable.storageIssue == nil && bytes(url) == fixed)
        print("PASS stale recovery, inaccessible source before/after load, read-only retry")
    }

    private static func receiptCopy(_ store: ReceiptStore) -> Receipt { store.receipts[0] }

    static func execution() async {
        for mode in EngineMode.allCases {
            for capable in [false, true] {
                for requested in [false, true] {
                    for tier in Tier.allCases {
                        for acknowledged in [false, true] {
                            let engine = Probe(mode, canWrite: capable)
                            var p = plan(tier); p.riskAcknowledged = acknowledged
                            let r = await OperationRunner.run(p, engine: engine, dryRun: requested, receiptID: 1) { _ in }
                            let preview = !capable || requested
                            let allowed = !preview && (tier == .reversible || acknowledged)
                            let writes = await engine.writes
                            precondition(r.dryRun == preview && writes == (allowed ? p.changes.map(\.target) : []))
                            precondition(r.items.allSatisfy { $0.outcome == (preview ? .simulated : allowed ? .verified : .skipped) })
                            precondition(r.status == (preview ? .simulated : allowed ? .complete : .failed))
                        }
                    }
                }
            }
        }
        print("PASS all modes × writable/read-only × preview/apply × tier × acknowledgement")
        for stop in [Receipt.Outcome.failed, .unverified] {
            for index in 0...2 {
                let p = plan(.reversible)
                let outcomes = Array(repeating: Receipt.Outcome.verified, count: index) + [stop]
                let engine = Probe(.demo, canWrite: true, returning: outcomes)
                let r = await OperationRunner.run(p, engine: engine, dryRun: false, receiptID: 2) { _ in }
                let writes = await engine.writes
                precondition(writes == Array(p.changes.prefix(index + 1).map(\.target)))
                precondition(r.items.map(\.outcome) == outcomes + Array(repeating: .skipped, count: 2 - index))
                precondition(!r.undoable && r.status == (index == 0 && stop == .failed ? .failed : .partial))
                let store = ReceiptStore(persist: false, seed: [r]); precondition(store.changeCount == index && r.reversibleCount == index)
            }
        }
        print("PASS stop on first failed/unverified key; skipped, partial and verified counts")
    }

    static func main() async throws {
        try storage(in: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
        await execution()
    }
}
