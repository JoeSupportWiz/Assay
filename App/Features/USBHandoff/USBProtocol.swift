import Foundation

/// v1 documents are flat JSON objects. Parse members before dictionary insertion:
/// general-purpose keyed decoders can silently coalesce duplicate names.
private struct ReceiptMembers {
    enum Scalar: Equatable { case text(String), flag(Bool) }
    let bytes: [UInt8]
    var i = 0
    var next: UInt8? { i < bytes.count ? bytes[i] : nil }

    mutating func take(_ byte: UInt8) -> Bool {
        while let c = next, [9, 10, 13, 32].contains(c) { i += 1 }
        guard next == byte else { return false }
        i += 1
        return true
    }

    mutating func string() throws -> String {
        guard take(34) else { throw USBFault.format }
        let start = i - 1
        while let c = next {
            i += 1
            if c == 92 { guard next != nil else { break }; i += 1 }
            if c == 34 {
                return try JSONDecoder().decode(String.self, from: Data(bytes[start..<i]))
            }
        }
        throw USBFault.format
    }

    mutating func parse() throws -> [String: Scalar] {
        guard take(123) else { throw USBFault.format }
        var values = [String: Scalar]()
        repeat {
            let key = try string()
            guard values.count < 7, values[key] == nil, take(58) else { throw USBFault.format }
            if take(116) {
                guard bytes[i...].starts(with: "rue".utf8) else { throw USBFault.format }
                i += 3; values[key] = .flag(true)
            } else if take(102) {
                guard bytes[i...].starts(with: "alse".utf8) else { throw USBFault.format }
                i += 4; values[key] = .flag(false)
            } else { values[key] = .text(try string()) }
        } while take(44)
        guard take(125) else { throw USBFault.format }
        while let c = next, [9, 10, 13, 32].contains(c) { i += 1 }
        guard next == nil else { throw USBFault.format }
        return values
    }
}

enum USBFault: Error { case format, wrongJob, time, size, changed }

struct USBPending: Equatable, Codable {
    let id: UUID
    let created: Date
    var request: Data {
        Data(#"{"schema":"assay.usb.request.v1","job_id":"\#(id.uuidString.lowercased())","operation":"standard_usb_backup"}"#.utf8)
    }
}

struct USBReceipt: Codable, Equatable {
    enum Outcome: String, Codable { case completed, unverified, failed, cancelled }
    let id: UUID
    let outcome: Outcome
    let started: Date
    let finished: Date
    // These flags are determined uniquely by the validated outcome.
    var toolSucceeded: Bool { outcome == .completed || outcome == .unverified }
    var manifestVerified: Bool { outcome == .completed }

    static let byteLimit = 4096
    static func validate(_ data: Data, for job: USBPending, now: Date) throws -> Self {
        guard data.count <= byteLimit else { throw USBFault.size }
        var parser = ReceiptMembers(bytes: Array(data))
        let fields = try parser.parse()
        guard fields.count == 7, fields["schema"] == .text("assay.usb.result.v1"),
              case let .text(rawID)? = fields["job_id"],
              case let .text(state)? = fields["state"], let outcome = Outcome(rawValue: state),
              case let .text(start)? = fields["started_at"], case let .text(end)? = fields["finished_at"],
              case let .flag(tool)? = fields["backup_tool_succeeded"],
              case let .flag(manifest)? = fields["fresh_manifest_verified"] else { throw USBFault.format }
        guard rawID.utf8.count == 36, UUID(uuidString: rawID) == job.id else { throw USBFault.wrongJob }
        let iso = ISO8601DateFormatter() // UTC, internet date/time, whole seconds
        func timestamp(_ s: String) throws -> Date {
            guard s.utf8.count == 20, let d = iso.date(from: s), iso.string(from: d) == s else { throw USBFault.time }
            return d
        }
        let started = try timestamp(start), finished = try timestamp(end)
        guard started.timeIntervalSince1970 >= floor(job.created.timeIntervalSince1970),
              finished >= started, finished <= now else { throw USBFault.time }
        let receipt = Self(id: job.id, outcome: outcome, started: started, finished: finished)
        guard tool == receipt.toolSucceeded, manifest == receipt.manifestVerified else { throw USBFault.format }
        return receipt
    }
}
