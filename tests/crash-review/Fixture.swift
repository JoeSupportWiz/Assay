import Foundation

@main enum CrashReviewFixture {
    static func parse(_ s: String) throws -> CrashEvidence { try CrashReview.parse(Data(s.utf8)) }
    static func rejects(_ expected: CrashReviewError, _ f: () throws -> CrashEvidence) {
        do { _ = try f(); fatalError("Expected rejection") }
        catch { precondition(error as? CrashReviewError == expected, "Wrong error category: \(expected)") }
    }
    static func main() throws {
        let sample = try CrashReview.parse(CrashReview.sample)
        precondition(sample.summary == """
        OS version: 17.4
        Mach exception: EXC_BAD_ACCESS — An attempted memory access failed.
        Termination namespace: SIGNAL
        Signal: SIGSEGV
        Crashing thread (one-based): 2
        Threads listed: 2
        """)
        let header = #"{"os_version":"iPhone OS 17.4 (21E219)","bug_type":"309","app_name":"PRIVATE"}"#
        let body = #"{"exception":{"type":"EXC_BAD_ACCESS","signal":"SIGSEGV","codes":"0xPRIVATE"},"termination":{"namespace":"SIGNAL","indicator":"PRIVATE"},"pid":432109,"procPath":"/PRIVATE","bundleInfo":{"CFBundleIdentifier":"PRIVATE"},"threads":[{}, {"triggered":true,"name":"PRIVATE","id":987654,"frames":[{"symbol":"PRIVATE"}]}]}"#
        let two = try parse(header + "\r\n" + body + "\n")
        precondition(two == sample) // Exact projection: none of the source's extra fields survives.
        let unknown = try parse(#"{"exception":{"type":"PRIVATE\nEXC_CRASH","signal":"SIGKILL/PRIVATE"},"termination":{"namespace":"PRIVATE"},"osVersion":{"train":"17.4\nPRIVATE"},"threads":[{},{}],"faultingThread":987654}"#)
        precondition([unknown.osVersion, unknown.exception, unknown.namespace, unknown.signal, unknown.ordinal].allSatisfy { $0 == "Unknown" } && unknown.total == "2")
        let missing = try parse("{\n\"exception\": {}\n}")
        precondition([missing.osVersion, missing.exception, missing.namespace, missing.signal, missing.ordinal, missing.total].allSatisfy { $0 == "Unavailable" })
        for index in ["-1", "2", "true", "\"1\"", "1.5", "9223372036854775808"] {
            let result = try parse("{\"exception\":{},\"faultingThread\":\(index),\"threads\":[{}, {\"triggered\":true}]}")
            precondition(result.ordinal == "Unknown" && result.total == "2")
        }
        let ambiguous = try parse(#"{"exception":{},"threads":[{"triggered":true},{"triggered":true}]}"#)
        precondition(ambiguous.ordinal == "Unknown")
        rejects(.malformed) { try parse(header + "\n" + String(body.dropLast())) }
        rejects(.malformed) { try parse(header) }
        rejects(.malformed) { try parse(header + "\n" + body + "\n{}") }
        rejects(.malformed) { try parse("") }
        rejects(.unsupported) { try parse(#"{"bug_type":"298"}"# + "\n" + body) }
        rejects(.unsupported) { try parse(#"{"processes":[],"memoryStatus":{},"exception":{}}"#) }
        rejects(.unsupported) { try parse(#"{"logs":[{"msg":"PRIVATE"}]}"#) }
        rejects(.unsupported) { try parse("unstructured log") }

        let manager = FileManager.default
        let dir = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: dir, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: dir) }
        let local = dir.appendingPathComponent("PRIVATE.IPS")
        let exact = CrashReview.sample + Data(repeating: 32, count: CrashReview.byteLimit - CrashReview.sample.count)
        try exact.write(to: local)
        let imported = try CrashReview.read(local)
        precondition(imported == sample)
        let over = exact + Data([32]); try over.write(to: local)
        rejects(.size) { try CrashReview.read(local) }; rejects(.size) { try CrashReview.parse(over) }
        rejects(.file) { try CrashReview.read(dir.appendingPathComponent("archive.zip")) }
        rejects(.file) { try CrashReview.read(URL(string: "https://example.invalid/test.ips")!) }
        let link = dir.appendingPathComponent("link.ips")
        try manager.createSymbolicLink(at: link, withDestinationURL: local)
        rejects(.file) { try CrashReview.read(link) }
        print("Crash review passed: projection, formats, rejection, local file and inclusive byte limits.")
    }
}
