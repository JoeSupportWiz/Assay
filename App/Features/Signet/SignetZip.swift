import Foundation
import Compression

// Minimal read-only ZIP central-directory reader. Foundation + Compression only.
// Supports stored (0) and deflate (8) entries. No ZIP64, no encryption, no multi-disk archives.
// Entries are extracted into memory on request and never written to disk.

enum SignetZipError: LocalizedError {
    case cannotOpen
    case tooLarge(Int64)
    case notZip
    case zip64Unsupported
    case corrupt(String)
    case unsafePath(String)
    case encrypted(String)
    case unsupportedMethod(String, Int)
    case entryTooLarge(String)
    case checksum(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen: return "The file could not be opened."
        case .tooLarge(let n): return "The file is \(ByteCountFormatter.string(fromByteCount: n, countStyle: .file)); the limit is 2 GB."
        case .notZip: return "This is not a ZIP archive, so it is not a valid .ipa."
        case .zip64Unsupported: return "ZIP64 archives are not supported in this version."
        case .corrupt(let s): return "The ZIP structure is damaged (\(s))."
        case .unsafePath(let p): return "Refused: the archive contains an unsafe path (\(p))."
        case .encrypted(let p): return "Entry \(p) is encrypted and cannot be read."
        case .unsupportedMethod(let p, let m): return "Entry \(p) uses compression method \(m), which is not supported."
        case .entryTooLarge(let p): return "Entry \(p) is larger than the 8 MB per-entry limit and was skipped."
        case .checksum(let p): return "Entry \(p) failed its CRC-32 check."
        }
    }
}

struct SignetZipEntry: Hashable {
    let name: String
    let method: Int
    let flags: Int
    let crc32: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
    var isDirectory: Bool { name.hasSuffix("/") }
}

final class SignetZipReader {
    static let maxFileBytes: Int64 = 2 * 1024 * 1024 * 1024
    static let maxEntryBytes = 8 * 1024 * 1024
    private static let maxCentralDirectoryBytes = 64 * 1024 * 1024

    private let handle: FileHandle
    let fileSize: Int64
    private(set) var entries: [SignetZipEntry] = []
    private var byName: [String: SignetZipEntry] = [:]

    init(url: URL) throws {
        guard let h = try? FileHandle(forReadingFrom: url) else { throw SignetZipError.cannotOpen }
        handle = h
        guard let end = try? h.seekToEnd() else { throw SignetZipError.cannotOpen }
        fileSize = Int64(end)
        if fileSize > Self.maxFileBytes { throw SignetZipError.tooLarge(fileSize) }
        if fileSize < 22 { throw SignetZipError.notZip }
        try readCentralDirectory()
    }

    deinit { try? handle.close() }

    func entry(named name: String) -> SignetZipEntry? { byName[name] }
    func hasEntry(_ name: String) -> Bool { byName[name] != nil }

    // MARK: Little-endian helpers

    private static func u16(_ b: [UInt8], _ o: Int) -> Int { Int(b[o]) | (Int(b[o + 1]) << 8) }
    private static func u32(_ b: [UInt8], _ o: Int) -> Int {
        Int(b[o]) | (Int(b[o + 1]) << 8) | (Int(b[o + 2]) << 16) | (Int(b[o + 3]) << 24)
    }

    private func read(at offset: Int64, count: Int) throws -> [UInt8] {
        guard offset >= 0, count >= 0, offset + Int64(count) <= fileSize else { throw SignetZipError.corrupt("read out of range") }
        if count == 0 { return [] }
        do {
            try handle.seek(toOffset: UInt64(offset))
            guard let d = try handle.read(upToCount: count), d.count == count else { throw SignetZipError.corrupt("short read") }
            return [UInt8](d)
        } catch let e as SignetZipError {
            throw e
        } catch {
            throw SignetZipError.corrupt("read failed")
        }
    }

    // MARK: Central directory

    private func readCentralDirectory() throws {
        // End Of Central Directory: 22 bytes + up to 65535 bytes of comment, searched backwards.
        let tailLen = Int(min(fileSize, 22 + 65535))
        let tailStart = fileSize - Int64(tailLen)
        let tail = try read(at: tailStart, count: tailLen)
        var eocd = -1
        var i = tailLen - 22
        while i >= 0 {
            if tail[i] == 0x50, tail[i + 1] == 0x4B, tail[i + 2] == 0x05, tail[i + 3] == 0x06 { eocd = i; break }
            i -= 1
        }
        if eocd < 0 { throw SignetZipError.notZip }
        let disk = Self.u16(tail, eocd + 4)
        let cdDisk = Self.u16(tail, eocd + 6)
        let total = Self.u16(tail, eocd + 10)
        let cdSize = Self.u32(tail, eocd + 12)
        let cdOffset = Self.u32(tail, eocd + 16)
        if total == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF { throw SignetZipError.zip64Unsupported }
        if disk != 0 || cdDisk != 0 { throw SignetZipError.corrupt("multi-disk archive") }
        if cdSize > Self.maxCentralDirectoryBytes { throw SignetZipError.corrupt("central directory too large") }
        if Int64(cdOffset) + Int64(cdSize) > fileSize { throw SignetZipError.corrupt("central directory out of range") }

        let cd = try read(at: Int64(cdOffset), count: cdSize)
        var p = 0
        var list: [SignetZipEntry] = []
        while p + 46 <= cd.count {
            guard cd[p] == 0x50, cd[p + 1] == 0x4B, cd[p + 2] == 0x01, cd[p + 3] == 0x02 else { break }
            let flags = Self.u16(cd, p + 8)
            let method = Self.u16(cd, p + 10)
            let crc = UInt32(truncatingIfNeeded: Self.u32(cd, p + 16))
            let comp = Self.u32(cd, p + 20)
            let uncomp = Self.u32(cd, p + 24)
            let nameLen = Self.u16(cd, p + 28)
            let extraLen = Self.u16(cd, p + 30)
            let commentLen = Self.u16(cd, p + 32)
            let lho = Self.u32(cd, p + 42)
            let next = p + 46 + nameLen + extraLen + commentLen
            if next > cd.count { throw SignetZipError.corrupt("entry overruns directory") }
            let nameBytes = Array(cd[(p + 46)..<(p + 46 + nameLen)])
            let name = String(decoding: nameBytes, as: UTF8.self)
            try Self.validate(path: name)
            list.append(SignetZipEntry(name: name, method: method, flags: flags, crc32: crc,
                                       compressedSize: comp, uncompressedSize: uncomp, localHeaderOffset: lho))
            p = next
        }
        entries = list
        var map: [String: SignetZipEntry] = [:]
        for e in list { map[e.name] = e }
        byName = map
    }

    /// Zip-slip guard: absolute paths, parent-directory segments, backslashes and NUL bytes are refused.
    static func validate(path: String) throws {
        if path.isEmpty { throw SignetZipError.unsafePath("(empty name)") }
        if path.hasPrefix("/") || path.contains("\\") || path.contains("\0") { throw SignetZipError.unsafePath(path) }
        for seg in path.split(separator: "/", omittingEmptySubsequences: false) where seg == ".." {
            throw SignetZipError.unsafePath(path)
        }
    }

    // MARK: Extraction (in memory only)

    func extract(_ entry: SignetZipEntry) throws -> Data {
        if entry.flags & 0x1 != 0 { throw SignetZipError.encrypted(entry.name) }
        if entry.compressedSize > Self.maxEntryBytes || entry.uncompressedSize > Self.maxEntryBytes {
            throw SignetZipError.entryTooLarge(entry.name)
        }
        let header = try read(at: Int64(entry.localHeaderOffset), count: 30)
        guard header[0] == 0x50, header[1] == 0x4B, header[2] == 0x03, header[3] == 0x04 else {
            throw SignetZipError.corrupt("bad local header for \(entry.name)")
        }
        let nameLen = Self.u16(header, 26)
        let extraLen = Self.u16(header, 28)
        let dataStart = Int64(entry.localHeaderOffset) + 30 + Int64(nameLen) + Int64(extraLen)
        let comp = try read(at: dataStart, count: entry.compressedSize)

        let out: [UInt8]
        switch entry.method {
        case 0:
            out = comp
        case 8:
            if entry.uncompressedSize == 0 { out = [] } else {
                var buffer = [UInt8](repeating: 0, count: entry.uncompressedSize)
                let size = buffer.count
                let n: Int = comp.withUnsafeBufferPointer { src in
                    buffer.withUnsafeMutableBufferPointer { dst in
                        guard let s = src.baseAddress, let d = dst.baseAddress else { return 0 }
                        // Apple's COMPRESSION_ZLIB is raw deflate, which is what ZIP stores.
                        return compression_decode_buffer(d, size, s, src.count, nil, COMPRESSION_ZLIB)
                    }
                }
                if n != entry.uncompressedSize { throw SignetZipError.corrupt("inflate failed for \(entry.name)") }
                out = buffer
            }
        default:
            throw SignetZipError.unsupportedMethod(entry.name, entry.method)
        }
        if out.count != entry.uncompressedSize { throw SignetZipError.corrupt("size mismatch for \(entry.name)") }
        if Self.crc32(out) != entry.crc32 { throw SignetZipError.checksum(entry.name) }
        return Data(out)
    }

    // MARK: CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    /// Streaming SHA-256 is done by the inspector; this exposes the raw handle size only.
    func readChunks(chunk: Int = 4 * 1024 * 1024, _ body: (Data) -> Void) throws {
        try handle.seek(toOffset: 0)
        while true {
            guard let d = try handle.read(upToCount: chunk), !d.isEmpty else { break }
            body(d)
        }
    }
}
