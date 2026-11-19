import Foundation

// Bounded TLV cursor. For CMS we need only ContentInfo → SignedData → encapContentInfo;
// unlike scanning for XML markers this does not mistake a plist elsewhere for the payload.
private struct PreflightNode {
    let tag: UInt8
    let body: Data.SubSequence
    var cursor: PreflightCursor { PreflightCursor(bytes: body) }
}

private struct PreflightCursor {
    var bytes: Data.SubSequence
    mutating func pop() throws -> UInt8 {
        guard let b = bytes.popFirst() else { throw PreflightFormatError.invalid }
        return b
    }
    mutating func take(_ count: Int) throws -> Data.SubSequence {
        guard count <= bytes.count else { throw PreflightFormatError.invalid }
        let result = bytes.prefix(count)
        bytes = bytes.dropFirst(count)
        return result
    }
    mutating func node(_ expected: UInt8? = nil, depth: Int = 0) throws -> PreflightNode {
        let tag = try pop(), length = try pop()
        guard tag != 0, tag & 31 != 31, expected == nil || tag == expected,
              depth < 16 else { throw PreflightFormatError.invalid }
        if length == 0x80 {
            guard tag & 0x20 != 0 else { throw PreflightFormatError.invalid }
            let start = bytes
            while !bytes.starts(with: [0, 0]) { _ = try node(depth: depth + 1) }
            let body = start.prefix(start.count - bytes.count)
            _ = try take(2)
            return PreflightNode(tag: tag, body: body)
        }
        var n = Int(length)
        if length > 0x80 {
            let width = Int(length & 127)
            guard width <= 4 else { throw PreflightFormatError.invalid }
            n = 0
            for byte in try take(width) { n = n * 256 + Int(byte) }
        }
        return try PreflightNode(tag: tag, body: take(n))
    }
    mutating func only(_ tag: UInt8) throws -> PreflightNode {
        let value = try node(tag)
        guard bytes.isEmpty else { throw PreflightFormatError.invalid }
        return value
    }
}

private enum PreflightFormatError: Error { case invalid }

enum SignerPreflightEnvelope {
    private static let pkcs7: [UInt8] = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 1, 7]

    static func payload(_ blob: Data) throws -> Data {
        var file = PreflightCursor(bytes: blob)
        var info = try file.only(0x30).cursor
        guard try info.node(6).body.elementsEqual(pkcs7 + [2]) else { throw PreflightFormatError.invalid }
        var wrapper = try info.only(0xa0).cursor
        var signed = try wrapper.only(0x30).cursor
        _ = try signed.node(2) // version
        _ = try signed.node(0x31) // digestAlgorithms (not evaluated)
        var encap = try signed.node(0x30).cursor
        guard try encap.node(6).body.elementsEqual(pkcs7 + [1]) else { throw PreflightFormatError.invalid }
        var content = try encap.only(0xa0).cursor
        let octets = try content.node()
        guard content.bytes.isEmpty else { throw PreflightFormatError.invalid }
        if octets.tag == 4 { return Data(octets.body) }
        guard octets.tag == 0x24 else { throw PreflightFormatError.invalid }
        var chunks = octets.cursor, result = Data()
        while !chunks.bytes.isEmpty { try result.append(chunks.node(4).body) }
        return result
    }

    /// Security parses the X.509 certificate; walk its standard TBSCertificate fields only
    /// for validity dates, without relying on macOS-only certificate-property APIs.
    static func certificateDates(_ der: Data) throws -> (Date?, Date?) {
        var file = PreflightCursor(bytes: der)
        var cert = try file.only(0x30).cursor
        var tbs = try cert.node(0x30).cursor
        if tbs.bytes.first == 0xa0 { _ = try tbs.node(0xa0) }
        _ = try tbs.node(2) // serial
        _ = try tbs.node(0x30) // signature algorithm
        _ = try tbs.node(0x30) // issuer
        var validity = try tbs.node(0x30).cursor
        let start = try date(validity.node()), end = try date(validity.node())
        guard validity.bytes.isEmpty else { throw PreflightFormatError.invalid }
        return (start, end)
    }

    private static func date(_ node: PreflightNode) -> Date? {
        let b = Array(node.body)
        guard (node.tag == 0x17 && b.count == 13) || (node.tag == 0x18 && b.count == 15),
              b.last == 90, b.dropLast().allSatisfy({ (48...57).contains($0) }) else { return nil }
        func digits(_ start: Int, _ length: Int) -> Int {
            b[start..<(start + length)].reduce(0) { $0 * 10 + Int($1 - 48) }
        }
        let y = b.count - 11
        var year = digits(0, y)
        if y == 2 { year += year < 50 ? 2000 : 1900 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = DateComponents(year: year, month: digits(y, 2), day: digits(y+2, 2),
                                   hour: digits(y+4, 2), minute: digits(y+6, 2), second: digits(y+8, 2))
        return parts.isValidDate(in: cal) ? cal.date(from: parts) : nil
    }
}
