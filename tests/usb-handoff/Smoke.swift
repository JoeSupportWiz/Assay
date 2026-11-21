import Foundation

@main struct Smoke {
    struct Failure: Error { let message: String }
    static func check(_ ok: Bool, _ message: String) throws {
        if !ok { throw Failure(message: message) }
    }
    static func rejects<T>(_ label: String, _ action: () throws -> T) throws {
        do { _ = try action() } catch { return }
        throw Failure(message: "Accepted: \(label)")
    }

    @MainActor static func main() throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let file = dir.appendingPathComponent("local.json")
        let store = USBJobStore(file: file)
        let now = Date(timeIntervalSince1970: 1_735_689_605) // 2025-01-01 00:00:05Z
        let created = now.addingTimeInterval(-4.25)
        guard case let .pending(job) = try store.create(replacing: .idle, now: created) else { throw Failure(message: "create") }
        let restarted = USBJobStore(file: file)
        try check(try restarted.load() == .pending(job), "pending survives restart")
        let id = job.id.uuidString.lowercased()
        let request = try JSONSerialization.jsonObject(with: job.request) as? [String: String]
        try check(request == ["schema": "assay.usb.request.v1", "operation": "standard_usb_backup", "job_id": id], "request contract")
        try rejects("silent replacement") { try store.create(replacing: .pending(job)) }
        try rejects("stale create") { try store.create(replacing: .idle) }
        let start = "2025-01-01T00:00:00Z", end = "2025-01-01T00:00:05Z"
        func json(_ state: String = "completed", _ tool: Bool = true, _ manifest: Bool = true) -> String {
            #"{"schema":"assay.usb.result.v1","job_id":"\#(id)","state":"\#(state)","started_at":"\#(start)","finished_at":"\#(end)","backup_tool_succeeded":\#(tool),"fresh_manifest_verified":\#(manifest)}"#
        }
        func validate(_ s: String) throws -> USBReceipt { try USBReceipt.validate(Data(s.utf8), for: job, now: now) }
        for state in ["completed", "unverified", "failed", "cancelled"] {
            for tool in [false, true] {
                for manifest in [false, true] {
                    let wire = json(state, tool, manifest)
                    if tool == ["completed", "unverified"].contains(state), manifest == (state == "completed") {
                        try check(try validate(wire).outcome.rawValue == state, "valid \(state)")
                    } else { try rejects("inconsistent flags") { try validate(wire) } }
                }
            }
        }
        let valid = json()
        for (a, b) in [(id, UUID().uuidString), (id, ""), ("result.v1", "result.v2"), ("completed", "ok"),
                       ("true", "1"), ("true", "\"true\""), ("true", "tfalse"), ("true", "null"), ("true", "{}"),
                       ("started_at", "extra"), ("}", ",\"extra\":true}"), ("}", ",}"),
                       ("{", #"{"sta\u0074e":"failed","#), ("}", "} x"), ("}", "}\u{0}"),
                       (",\"state\":\"completed\"", ""), (start, "2024-12-31T23:59:59Z"),
                       (start, "2025-01-01T00:00:06Z"), (end, "2025-01-01T00:00:06Z"),
                       (start, "2025-01-01T00:00:01.000Z"), (start, "2025-01-01T00:00:01+00:00"),
                       (start, "2024-12-32T00:00:00Z"), (end, "2025-01-01T00:00:60Z")] {
            try rejects("invalid receipt: \(a)") { try validate(valid.replacingOccurrences(of: a, with: b)) }
        }
        let padded = valid.padding(toLength: USBReceipt.byteLimit, withPad: " ", startingAt: 0)
        _ = try validate(padded)
        try rejects("over limit") { try validate(padded + " ") }
        let input = dir.appendingPathComponent("result.json")
        try Data(padded.utf8).write(to: input)
        try check(try readUSBFile(input).count == USBReceipt.byteLimit, "bounded read at limit")
        try Data((padded + " ").utf8).write(to: input)
        try rejects("oversized file") { try readUSBFile(input) }
        try rejects("directory") { try readUSBFile(dir) }
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        try rejects("symlink") { try readUSBFile(link) }
        try rejects("request as result") { try store.accept(job.request, for: job, now: now) }
        try check(try store.load() == .pending(job), "rejection did not consume job")
        let data = Data(valid.utf8)
        let done = try restarted.accept(data, for: job, now: now)
        try check(try USBJobStore(file: file).load() == done, "result survives restart")
        try rejects("replay") { try store.accept(data, for: job, now: now) }
        guard case let .pending(other) = try store.create(replacing: done, now: created) else { throw Failure(message: "new job") }
        try check(other.id != job.id, "fresh UUID")
        try rejects("receipt after replacement") { try store.accept(data, for: other, now: now) }
        try rejects("stale abandonment") { try store.abandon(job) }
        _ = try store.abandon(other)
        try check(try restarted.load() == .idle, "abandon survives restart")
        try rejects("late receipt after abandon") { try store.accept(Data(valid.replacingOccurrences(of: id, with: other.id.uuidString).utf8), for: other, now: now) }
        try Data("damaged state".utf8).write(to: file)
        try rejects("corrupt store must fail closed") { try store.create(replacing: .idle) }
        print("PASS: SwiftUI parse; wire contract, state/flag matrix, strict JSON/UTC, size bounds, restart, abandonment and replay")
    }
}
