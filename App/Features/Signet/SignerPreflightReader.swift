import Foundation
import Security
import CryptoKit

struct SignerPublicCertificate {
    let digest: Data
    let starts: Date?
    let expires: Date?
}

struct SignerProfileClaims {
    let certificates: [Data?]?
    let expires: Date?
    let pattern: String?
}

enum SignerPreflightError: String, Error {
    case certificate = "Choose one public X.509 certificate (.cer or .pem), not a key, chain, or identity archive."
    case profile = "Choose a .mobileprovision with a readable encapsulated profile plist."
    case file = "Cannot read this selection as a local regular file."
    case size = "Selection is empty or exceeds its size limit."
}

enum SignerPreflightReader {
    static let maxProfiles = 6
    private static let certLimit = 64 * 1024
    private static let profileLimit = 2 * 1024 * 1024

    private static func read(_ url: URL, limit: Int) throws -> Data {
        guard url.isFileURL else { throw SignerPreflightError.file }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true else { throw SignerPreflightError.file }
        guard (info.fileSize ?? 0) <= limit else { throw SignerPreflightError.size }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var bytes = Data()
        while true {
            try Task.checkCancellation()
            let length = min(64 * 1024, limit + 1 - bytes.count)
            guard let chunk = try handle.read(upToCount: length), !chunk.isEmpty else { break }
            bytes.append(chunk)
            guard bytes.count <= limit else { throw SignerPreflightError.size }
        }
        guard !bytes.isEmpty else { throw SignerPreflightError.size }
        return bytes
    }

    static func certificate(_ url: URL) throws -> SignerPublicCertificate {
        let ext = url.pathExtension.lowercased()
        guard ext == "cer" || ext == "pem" else { throw SignerPreflightError.certificate }
        let file = try read(url, limit: certLimit)
        let der: Data
        if file.first == 0x30 && ext == "cer" {
            der = file
        } else {
            guard let text = String(data: file, encoding: .ascii) else { throw SignerPreflightError.certificate }
            let lines = text.split(whereSeparator: { $0.isNewline })
            guard lines.count >= 3, lines.first == "-----BEGIN CERTIFICATE-----",
                  lines.last == "-----END CERTIFICATE-----",
                  let data = Data(base64Encoded: lines.dropFirst().dropLast().joined()) else {
                throw SignerPreflightError.certificate
            }
            der = data
        }
        // Whole-object framing also rejects a certificate followed by other DER/PEM material.
        guard let digest = fingerprint(der), let dates = try? SignerPreflightEnvelope.certificateDates(der) else {
            throw SignerPreflightError.certificate
        }
        return SignerPublicCertificate(digest: digest, starts: dates.0, expires: dates.1)
    }

    private static func fingerprint(_ der: Data) -> Data? {
        guard !der.isEmpty, der.count <= certLimit,
              let cert = SecCertificateCreateWithData(nil, der as CFData),
              SecCertificateCopyData(cert) as Data == der else { return nil }
        return Data(SHA256.hash(data: der))
    }

    static func profile(_ url: URL) throws -> SignerProfileClaims {
        guard url.pathExtension.lowercased() == "mobileprovision" else { throw SignerPreflightError.profile }
        let file = try read(url, limit: profileLimit)
        guard let plist = try? SignerPreflightEnvelope.payload(file),
              let root = (try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil)) as? [String: Any]
        else { throw SignerPreflightError.profile }
        // Keep no raw plist, names, device identifiers, URLs or certificate bytes in view state.
        var digests: [Data?]?
        if let entries = root["DeveloperCertificates"] as? [Any], entries.count <= 32 {
            digests = entries.map { ($0 as? Data).flatMap(fingerprint) }
        }
        let entitlements = root["Entitlements"] as? [String: Any]
        let pattern = SignerPreflightRules.pattern(entitlements?["application-identifier"] as? String,
                                                   prefixes: root["ApplicationIdentifierPrefix"] as? [String])
        return SignerProfileClaims(certificates: digests, expires: root["ExpirationDate"] as? Date, pattern: pattern)
    }
}
