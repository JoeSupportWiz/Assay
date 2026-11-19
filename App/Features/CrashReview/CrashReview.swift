import Foundation
import CoreFoundation

enum CrashReviewError: String, Error {
    case file = "Choose a local, regular .ips file that can be opened."
    case size = "The file exceeds the 5 MiB limit."
    case malformed = "The report is empty, incomplete or not readable JSON."
    case unsupported = "This is not a supported app crash report. Jetsam, panic and other analytics logs need a different reader."
}

/// Only the projection survives parsing. No source dictionaries, URLs, or free-form report text.
struct CrashEvidence: Equatable, Sendable {
    let osVersion, exception, namespace, signal, ordinal, total: String
    var summary: String {
        "OS version: \(osVersion)\nMach exception: \(exception)\nTermination namespace: \(namespace)\nSignal: \(signal)\nCrashing thread (one-based): \(ordinal)\nThreads listed: \(total)"
    }
}

enum CrashReview {
    static let byteLimit = 5 * 1024 * 1024
    static let sample = Data(#"{"bug_type":"309","osVersion":{"train":"iPhone OS 17.4"},"exception":{"type":"EXC_BAD_ACCESS","signal":"SIGSEGV"},"termination":{"namespace":"SIGNAL"},"faultingThread":1,"threads":[{},{}]}"#.utf8)
    private typealias Object = [String: Any]
    private static let unknown = "Unknown", absent = "Unavailable"

    private static let exceptions = [
        "EXC_BAD_ACCESS": "EXC_BAD_ACCESS — An attempted memory access failed.",
        "EXC_BAD_INSTRUCTION": "EXC_BAD_INSTRUCTION — The processor encountered an invalid instruction.",
        "EXC_ARITHMETIC": "EXC_ARITHMETIC — The processor reported an arithmetic fault.",
        "EXC_BREAKPOINT": "EXC_BREAKPOINT — Execution stopped at a breakpoint or trap.",
        "EXC_CRASH": "EXC_CRASH — A signal ended the process.",
        "EXC_RESOURCE": "EXC_RESOURCE — The system reported a resource limit.",
        "EXC_GUARD": "EXC_GUARD — The system reported a protected resource violation.",
        "EXC_SOFTWARE": "EXC_SOFTWARE — Software raised an exception.",
        "EXC_EMULATION": "EXC_EMULATION — The processor reported an instruction emulation exception.",
        "EXC_CORPSE_NOTIFY": "EXC_CORPSE_NOTIFY — The system recorded a process termination."
    ]
    private static let namespaces = ["SIGNAL", "DYLD", "CODESIGNING", "FRONTBOARD", "SPRINGBOARD", "RUNNINGBOARD", "JETSAM", "WATCHDOG", "TCC", "LIBSYSTEM", "LIBXPC", "GUARD"]
    private static let signals = ["SIGABRT", "SIGBUS", "SIGSEGV", "SIGILL", "SIGTRAP", "SIGFPE", "SIGKILL", "SIGTERM", "SIGQUIT", "SIGSYS", "SIGPIPE"]

    private static func missing(_ value: Any?) -> Bool { value == nil || value is NSNull }
    private static func field(_ root: Object, _ group: String, _ key: String) -> Any? {
        if let obj = root[group] as? Object { return obj[key] }
        return root[group] // Nil/null is unavailable; a malformed group is unknown, never a field value.
            .map { missing($0) ? NSNull() as Any : false as Any }
    }
    private static func allow(_ value: Any?, _ values: [String]) -> String {
        guard !missing(value) else { return absent }
        return values.first { $0 == value as? String } ?? unknown
    }
    private static func version(_ value: Any?) -> String {
        guard !missing(value) else { return absent }
        guard let s = value as? String, s.utf8.count <= 80 else { return unknown }
        // Match a full train/version, not a digit sequence inside an arbitrary name or path.
        let pattern = #"\A(?:(?:iPhone OS|iPadOS|iOS) )?([0-9]{1,2}(?:\.[0-9]{1,2}){0,2})(?: \([0-9]{1,2}[A-Z][0-9]{1,5}[a-z]?\))?\z"#
        guard let m = (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: 1), in: s) else { return unknown }
        return s[r].split(separator: ".").compactMap { Int($0) }.map(String.init).joined(separator: ".")
    }
    private static func integer(_ v: Any?) -> Int? {
        guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return Int(n.stringValue)
    }
    private static func threads(_ body: Object) -> (ordinal: String, total: String) {
        guard let list = body["threads"] as? [Object] else {
            return (missing(body["faultingThread"]) ? absent : unknown, missing(body["threads"]) ? absent : unknown)
        }
        let count = String(list.count)
        let index = body["faultingThread"]
        if !missing(index) {
            guard let i = integer(index), list.indices.contains(i) else { return (unknown, count) }
            return (String(i + 1), count)
        }
        var marked: Int?
        for (i, thread) in list.enumerated() where !missing(thread["triggered"]) {
            guard let flag = thread["triggered"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() else { return (unknown, count) }
            if flag.boolValue {
                guard marked == nil else { return (unknown, count) }
                marked = i + 1
            }
        }
        return (marked.map(String.init) ?? absent, count)
    }

    private static func checkFormat(_ obj: Object) throws {
        if !missing(obj["bug_type"]) {
            let type = obj["bug_type"] as? String ?? integer(obj["bug_type"]).map(String.init)
            guard type == "309" || type == "109" else { throw CrashReviewError.unsupported }
        }
        let nonCrash = ["memoryStatus", "largestProcess", "processes", "panicString", "logMessages", "logs", "log"]
        guard !nonCrash.contains(where: { obj[$0] != nil }) else { throw CrashReviewError.unsupported }
    }

    static func parse(_ bytes: Data) throws -> CrashEvidence {
        guard bytes.count <= byteLimit else { throw CrashReviewError.size }
        func whitespace(_ c: UInt8) -> Bool { c == 32 || c == 9 || c == 10 || c == 13 }
        guard let start = bytes.firstIndex(where: { !whitespace($0) }) else { throw CrashReviewError.malformed }
        guard bytes[start] == 123 else { throw CrashReviewError.unsupported }
        func object(_ data: Data) -> Object? { (try? JSONSerialization.jsonObject(with: data)) as? Object }
        let data = bytes[start...]
        var header = Object(), payload = data
        if let lf = data.firstIndex(of: 10), let first = object(data[..<lf]),
           data[lf...].contains(where: { !whitespace($0) }) {
            try checkFormat(first)
            header = first
            payload = data[lf...]
        }
        guard let body = object(payload) else { throw CrashReviewError.malformed }
        try checkFormat(body)
        guard body["exception"] is Object || (body["threads"] is [Any] && (body["faultingThread"] != nil || body["termination"] is Object)) else {
            if body["bug_type"] != nil && body["os_version"] != nil { throw CrashReviewError.malformed } // Header only.
            throw CrashReviewError.unsupported
        }
        let rawType = field(body, "exception", "type")
        let exception = (rawType as? String).flatMap { exceptions[$0] } ?? (missing(rawType) ? absent : unknown)
        let train = field(body, "osVersion", "train")
        let (ordinal, total) = threads(body)
        return CrashEvidence(osVersion: version(missing(train) ? body["os_version"] ?? header["os_version"] : train),
                             exception: exception, namespace: allow(field(body, "termination", "namespace"), namespaces),
                             signal: allow(field(body, "exception", "signal"), signals), ordinal: ordinal, total: total)
    }

    static func read(_ url: URL) throws -> CrashEvidence {
        guard url.isFileURL, (url.host ?? "").isEmpty || url.host == "localhost", url.pathExtension.lowercased() == "ips" else { throw CrashReviewError.file }
        #if canImport(Darwin)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        #endif
        do {
            let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard info.isRegularFile == true, info.isSymbolicLink != true else { throw CrashReviewError.file }
            guard (info.fileSize ?? 0) <= byteLimit else { throw CrashReviewError.size }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var bytes = Data()
            while let chunk = try handle.read(upToCount: min(65536, byteLimit + 1 - bytes.count)), !chunk.isEmpty {
                bytes.append(chunk)
                guard bytes.count <= byteLimit else { throw CrashReviewError.size }
            }
            return try parse(bytes)
        } catch let e as CrashReviewError { throw e }
        catch { throw CrashReviewError.file } // Never display a URL-bearing Foundation error.
    }
}
