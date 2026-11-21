import Foundation
import Security

/// API keys live here and nowhere else: not in UserDefaults, URLs, prompts, logs or exports.
enum AIKeychain {
    static let service = "com.joesupportwiz.assay.ai"

    enum KeychainError: LocalizedError {
        case empty, invalidCharacters, tooLong, failed
        var errorDescription: String? {
            switch self {
            case .empty: return "Paste a key first."
            case .invalidCharacters: return "That does not look like an API key. It contains spaces or unusual characters."
            case .tooLong: return "That is too long to be an API key."
            case .failed: return "The key could not be saved to the Keychain."
            }
        }
    }

    private static func baseQuery(_ kind: AIProviderKind, endpoint: String? = nil) -> [String: Any] {
        // A custom credential is valid only for its configured endpoint, never for the next server entered.
        let account = kind.isHostedService ? kind.rawValue : kind.rawValue + "|" + (endpoint ?? AIStoredSettings.load().baseURL(for: kind))
        return [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Cleans pasted text and checks it is safe to put in an HTTP header.
    static func sanitise(_ raw: String) throws -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { throw KeychainError.empty }
        if key.count > 512 { throw KeychainError.tooLong }
        for scalar in key.unicodeScalars where scalar.value < 0x21 || scalar.value > 0x7E { throw KeychainError.invalidCharacters }
        return key
    }

    static func save(_ raw: String, for kind: AIProviderKind) throws {
        let key = try sanitise(raw)
        guard let data = key.data(using: .utf8) else { throw KeychainError.invalidCharacters }
        let query = baseQuery(kind)
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.failed }
    }

    static func delete(for kind: AIProviderKind) {
        SecItemDelete(baseQuery(kind) as CFDictionary)
    }

    /// Existence check that never reads the secret.
    static func has(for kind: AIProviderKind) -> Bool {
        var q = baseQuery(kind)
        q[kSecReturnData as String] = false
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    /// Only AIClient should call this, to build an auth header.
    static func read(for kind: AIProviderKind, endpoint: String? = nil) -> String? {
        var q = baseQuery(kind, endpoint: endpoint)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let s = String(data: data, encoding: .utf8), !s.isEmpty else { return nil }
        return s
    }

    /// "••••" plus the last four characters. Short keys show only the dots.
    static func masked(for kind: AIProviderKind) -> String? {
        guard let key = read(for: kind) else { return nil }
        return mask(key)
    }

    static func mask(_ key: String) -> String {
        key.count >= 12 ? "••••" + String(key.suffix(4)) : "••••"
    }
}
