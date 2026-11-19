import Foundation

/// Optional, local-only log projection. Never retain or serialise log lines, paths or arbitrary text.
struct MinisTransport: Encodable, Equatable, Sendable {
    var heartbeatSamples = 0
    var maxHostIdleSeconds: Int?
    var explicitResetLines = 0
    var completionLines = 0
    var lastReportedPercent: Int?

    static func summarise(_ text: String) -> Self {
        var r = Self()
        // Parse values only on known backup heartbeats. Counters reset between retries/runs: never add file counts.
        let idle = try! NSRegularExpression(pattern: #"host callbacks idle ([0-9]{1,7})s(?:,| |$)"#)
        let percent = try! NSRegularExpression(pattern: #"progress=([0-9]{1,3})%(?: |,|$)"#)
        func n(_ re: NSRegularExpression, _ line: String) -> Int? {
            let ns = line as NSString
            guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
            return Int(ns.substring(with: m.range(at: 1)))
        }
        text.enumerateLines { line, _ in
            guard line.utf8.count <= 4096 else { return }
            if line.hasPrefix("⏱ protective backup:"), line.contains("s elapsed"), line.contains("streamed=") {
                r.heartbeatSamples += 1
                if let v = n(idle, line) { r.maxHostIdleSeconds = max(v, r.maxHostIdleSeconds ?? 0) }
                if let v = n(percent, line), v <= 100 { r.lastReportedPercent = v }
            }
            if (line.hasPrefix("protective backup attempt ") && line.contains("ConnectionReset")) || line.contains(" WARN RST on hp=") { r.explicitResetLines += 1 }
            if line.hasPrefix("Restore confirmed complete: device verdict 0,") { r.completionLines += 1 }
        }
        return r
    }

    static func fromFile(_ url: URL) throws -> Self {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let cap = 8 * 1024 * 1024
        var bytes = Data()
        while bytes.count <= cap, let d = try handle.read(upToCount: min(64 * 1024, cap + 1 - bytes.count)), !d.isEmpty { bytes.append(d) }
        guard bytes.count <= cap, !bytes.contains(0), let text = String(data: bytes, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        let r = summarise(text)
        guard r.heartbeatSamples + r.explicitResetLines + r.completionLines > 0 else { throw CocoaError(.fileReadUnknown) }
        return r
    }
}
