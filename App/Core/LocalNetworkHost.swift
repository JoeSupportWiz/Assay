#if canImport(Darwin)
import Darwin
#elseif canImport(Musl)
import Musl
#else
import Glibc
#endif

/// Syntactic destination policy; never resolves DNS or consults the current network.
/// Input is a bare host, not a URL. Unrecognised or ambiguous spellings are not local.
enum LocalNetworkHost {
    case loopback, privateIPv4, linkLocal, uniqueLocalIPv6, localName, other

    static func classify(_ host: String) -> Self {
        // In particular, never pass an embedded NUL to a C string parser.
        guard !host.isEmpty, host.utf8.count <= 254,
              host.utf8.allSatisfy({ (33...126).contains($0) }) else { return .other }
        if host.contains(":") { return ipv6(host) }

        // Only canonical dotted decimal. Some transports interpret leading zeroes as octal.
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ p in
            !p.isEmpty && (p.count == 1 || p.first != "0") && p.utf8.allSatisfy(isDigit) && UInt8(p) != nil
        }), let a = UInt8(parts[0]), let b = UInt8(parts[1]) {
            if a == 127 { return .loopback }
            if a == 10 || (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168) { return .privateIPv4 }
            if a == 169 && b == 254 { return .linkLocal }
            return .other // Includes carrier/shared space 100.64.0.0/10.
        }

        // A single final DNS root dot is valid on a name, not on an IP literal.
        let name = (host.hasSuffix(".") ? String(host.dropLast()) : host).lowercased()
        if name == "localhost" { return .loopback }
        guard name.utf8.count <= 253, name.hasSuffix(".local") else { return .other }
        for label in name.split(separator: ".", omittingEmptySubsequences: false) {
            guard (1...63).contains(label.utf8.count), label.first != "-", label.last != "-",
                  label.utf8.allSatisfy({ isLetter($0) || isDigit($0) || $0 == 45 }) else { return .other }
        }
        return .localName
    }

    private static func ipv6(_ host: String) -> Self {
        let parts = host.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
        var addr = in6_addr()
        guard inet_pton(AF_INET6, String(parts[0]), &addr) == 1 else { return .other }
        return withUnsafeBytes(of: &addr) { bytes in
            if bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80 {
                return parts.count == 1 || validScope(parts[1]) ? .linkLocal : .other
            }
            guard parts.count == 1 else { return .other } // Zone IDs are for link-local here, not ULA/loopback.
            if bytes[0] & 0xfe == 0xfc { return .uniqueLocalIPv6 }
            if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return .loopback }
            return .other // Includes IPv4-mapped IPv6; never reclassify its embedded IPv4 address.
        }
    }

    /// A positive interface index or a simple interface name (e.g. en0, awdl0, utun2).
    /// Check syntax, not interface presence. Never discard arbitrary text following `%`.
    private static func validScope(_ scope: Substring) -> Bool {
        guard let first = scope.utf8.first, scope.utf8.count < Int(IF_NAMESIZE) else { return false }
        if isDigit(first) { return first != 48 && scope.utf8.allSatisfy(isDigit) && UInt32(scope) != nil }
        return isLetter(first) && scope.utf8.allSatisfy { isLetter($0) || isDigit($0) || $0 == 45 || $0 == 95 }
    }

    private static func isLetter(_ b: UInt8) -> Bool { (65...90).contains(b) || (97...122).contains(b) }
    private static func isDigit(_ b: UInt8) -> Bool { (48...57).contains(b) }
}
