import Foundation

/// A result describes only the named observation, never the validity of an identity or profile.
enum SignerObservation: String {
    case yes = "Match", no = "Mismatch", unknown = "Unknown"
}

enum SignerPreflightRules {
    static func expiry(_ end: Date?, asOf now: Date) -> SignerObservation {
        guard let end else { return .unknown }
        return now < end ? .yes : .no
    }

    /// A readable match is sufficient evidence of inclusion. Incomplete data cannot prove absence.
    static func membership(_ selected: Data?, in entries: [Data?]?) -> SignerObservation {
        guard let selected, let entries else { return .unknown }
        if entries.contains(selected) { return .yes }
        return entries.contains(nil) ? .unknown : .no
    }

    static func bundleID(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 255 else { return false }
        return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 45
            }
        }
    }

    /// Strip only a declared App ID prefix (which need not equal TeamIdentifier).
    static func pattern(_ identifier: String?, prefixes: [String]?) -> String? {
        guard let identifier, identifier.utf8.count <= 512, let dot = identifier.firstIndex(of: "."),
              prefixes?.contains(String(identifier[..<dot])) == true, dot != identifier.startIndex else { return nil }
        let suffix = String(identifier[identifier.index(after: dot)...])
        if suffix == "*" || bundleID(suffix) { return suffix }
        guard suffix.hasSuffix(".*"), bundleID(String(suffix.dropLast(2))) else { return nil }
        return suffix
    }

    static func target(_ bundle: String?, allowedBy pattern: String?) -> SignerObservation {
        guard let bundle, bundleID(bundle), let pattern else { return .unknown }
        if pattern == "*" { return .yes }
        if pattern.hasSuffix(".*"), bundleID(String(pattern.dropLast(2))) {
            return bundle.hasPrefix(String(pattern.dropLast())) ? .yes : .no
        }
        guard bundleID(pattern) else { return .unknown }
        return bundle == pattern ? .yes : .no
    }
}
