import Foundation

// MARK: - Where does the text go?

/// Plain-language answer to "where does this message end up?". Always shown next to a provider.
enum AIPrivacyLabel: String, Equatable {
    case leavesPhone, staysOnLAN, staysOnPhone

    var title: String {
        switch self {
        case .leavesPhone: return "Leaves your phone"
        case .staysOnLAN: return "Stays on your LAN"
        case .staysOnPhone: return "Stays on this phone"
        }
    }

    var detail: String {
        switch self {
        case .leavesPhone: return "Your messages are sent over the internet to a company's servers and handled under their terms."
        case .staysOnLAN: return "Your messages go to a device on your own network. They do not leave it unless that device forwards them."
        case .staysOnPhone: return "Your messages go to a server running on this phone. They are not sent anywhere else by Assay."
        }
    }

    var symbol: String {
        switch self {
        case .leavesPhone: return "arrow.up.forward.app"
        case .staysOnLAN: return "wifi.router"
        case .staysOnPhone: return "iphone"
        }
    }

    /// Needs the first-message confirmation sheet.
    var needsConsent: Bool { self == .leavesPhone }

    static func forProvider(_ kind: AIProviderKind, baseURL: String) -> AIPrivacyLabel {
        if kind.isHostedService { return .leavesPhone }
        return AIHost.privacyLabel(forBaseURL: baseURL)
    }
}

/// Address classification. A name we cannot place (anything that is not localhost, a private address or .local)
/// is treated as hosted: the safe assumption.
enum AIHost {
    static func privacyLabel(forBaseURL base: String) -> AIPrivacyLabel {
        guard let host = parse(base)?.host else { return .leavesPhone }
        return classify(host: host)
    }

    static func parse(_ base: String) -> URL? {
        let s = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let u = URL(string: s), let scheme = u.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = u.host, !host.isEmpty,
              u.user == nil, u.password == nil else { return nil }
        return u
    }

    static func classify(host rawHost: String) -> AIPrivacyLabel {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]."))
        if host == "localhost" || host.hasSuffix(".localhost") { return .staysOnPhone }
        if host == "::1" { return .staysOnPhone }
        if host.hasSuffix(".local") { return .staysOnLAN }
        if host.contains(":") {
            // IPv6 literal: fe80::/10 link-local, fc00::/7 unique local.
            if host.hasPrefix("fe8") || host.hasPrefix("fe9") || host.hasPrefix("fea") || host.hasPrefix("feb") { return .staysOnLAN }
            if host.hasPrefix("fc") || host.hasPrefix("fd") { return .staysOnLAN }
            return .leavesPhone
        }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        if parts.count == 4, parts.allSatisfy({ $0 >= 0 && $0 <= 255 }), host.split(separator: ".").count == 4 {
            let a = parts[0], b = parts[1]
            if a == 127 { return .staysOnPhone }
            if a == 10 { return .staysOnLAN }
            if a == 172 && (16...31).contains(b) { return .staysOnLAN }
            if a == 192 && b == 168 { return .staysOnLAN }
            if a == 169 && b == 254 { return .staysOnLAN }
            if a == 100 && (64...127).contains(b) { return .staysOnLAN }   // private mesh (CGNAT) range
        }
        return .leavesPhone
    }
}

// MARK: - Redaction

struct AIRedaction: Equatable {
    var text: String
    var count: Int
    var categories: [String]
}

/// Strips identifiers and secrets from outgoing text. Idempotent: running it twice changes nothing more.
/// It is a safety net, not a guarantee, so the preview sheet always shows exactly what will be sent.
enum AIRedactor {
    private struct Rule {
        let category: String
        let replacement: String
        let regex: NSRegularExpression
        let validate: ((String) -> Bool)?
    }

    private static func rule(_ category: String, _ replacement: String, _ pattern: String, validate: ((String) -> Bool)? = nil) -> Rule? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        return Rule(category: category, replacement: replacement, regex: re, validate: validate)
    }

    private static func hasDigit(_ s: String) -> Bool { s.rangeOfCharacter(from: .decimalDigits) != nil }
    private static func hasLetter(_ s: String) -> Bool { s.rangeOfCharacter(from: .letters) != nil }

    private static let rules: [Rule] = [
        // Key material first, so nothing inside it is half-matched by a later rule.
        rule("key material", "[redacted key material]",
             #"-----BEGIN [A-Z0-9 ]+-----[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)"#),
        rule("key material", "[redacted key material]",
             #"\b(?:sk-(?:ant-|or-|proj-)?[A-Za-z0-9_\-]{16,}|AIza[0-9A-Za-z_\-]{30,}|gsk_[A-Za-z0-9]{20,}|xox[a-z]-[A-Za-z0-9\-]{10,})"#),
        rule("key material", "[redacted key material]",
             #"(?i)\bbearer\s+[A-Za-z0-9._~+/\-]{16,}=*"#),
        rule("pairing or key material", "[redacted pairing/key material]",
             #"(?i)\b(?:pair(?:ing)?(?:\s*record)?|host\s?id|system\s?buid|escrow\s?bag|(?:device|host|root)\s?certificate|private\s?key|public\s?key|api[\s_\-]?key|secret|token|password|passcode)\b\s*[:=]\s*\S+"#),
        rule("UDID", "[redacted UDID]",
             #"\b[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4,16}){1,4}\b"#, validate: { AIRedactor.hasDigit($0) }),
        rule("UDID", "[redacted UDID]",
             #"\b[0-9A-Fa-f]{40}\b"#, validate: { AIRedactor.hasDigit($0) }),
        rule("ECID", "[redacted ECID]",
             #"(?i)\bECID\b\s*[:=]?\s*(?:0x)?[0-9a-f]{6,16}\b"#, validate: { AIRedactor.hasDigit($0) }),
        rule("ECID", "[redacted ECID]",
             #"\b0x[0-9A-Fa-f]{12,16}\b"#),
        rule("serial number", "[redacted serial]",
             #"(?i)\b(?:serial(?:\s*(?:number|no\.?))?|S/N|IMEI|MEID)\b\s*(?:is\s+)?[:=#]?\s*[A-Z0-9]{8,17}\b"#, validate: { AIRedactor.hasDigit($0) }),
        rule("serial number", "[redacted serial]",
             #"\b(?=[A-Z0-9]*[0-9])(?=[A-Z0-9]*[A-Z])[A-Z0-9]{10,12}\b"#),
        rule("serial number", "[redacted serial]",
             #"\b[0-9]{15}\b"#),
        rule("network address", "[redacted address]",
             #"\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b"#),
        rule("pairing or key material", "[redacted pairing/key material]",
             #"[A-Za-z0-9+/_\-]{40,}={0,2}"#, validate: { ($0.count >= 64) || (AIRedactor.hasDigit($0) && AIRedactor.hasLetter($0)) })
    ].compactMap { $0 }

    static func redact(_ text: String) -> AIRedaction {
        var result = text
        var total = 0
        var cats: [String] = []
        for r in rules {
            let ns = result as NSString
            let matches = r.regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            if matches.isEmpty { continue }
            var current = result as NSString
            var hit = 0
            for m in matches.reversed() {
                let piece = ns.substring(with: m.range)
                if let v = r.validate, !v(piece) { continue }
                current = current.replacingCharacters(in: m.range, with: r.replacement) as NSString
                hit += 1
            }
            if hit > 0 {
                result = current as String
                total += hit
                if !cats.contains(r.category) { cats.append(r.category) }
            }
        }
        return AIRedaction(text: result, count: total, categories: cats)
    }

    /// Redacts a whole outgoing request. Messages keep their roles.
    static func prepare(system: String?, messages: [AIMessage]) -> AIOutgoing {
        var total = 0
        var cats: [String] = []
        func run(_ s: String) -> String {
            let r = redact(s)
            total += r.count
            for c in r.categories where !cats.contains(c) { cats.append(c) }
            return r.text
        }
        let sys = run(system ?? "")
        var out: [AIMessage] = []
        for m in messages {
            var copy = m
            let before = total
            copy.content = run(m.content)
            copy.redactedCount = total - before
            out.append(copy)
        }
        return AIOutgoing(system: sys, messages: out, redactedCount: total, categories: cats)
    }
}

// MARK: - Settings (no secrets)

struct AIResolved: Equatable {
    var provider: AIProviderKind
    var model: String
    var baseURL: String
}

/// Everything about AI that may live in UserDefaults. API keys never do; they live in AIKeychain.
struct AIStoredSettings: Codable, Equatable {
    var defaultProvider: AIProviderKind = .openAI
    var baseURLs: [String: String] = [:]
    var models: [String: String] = [:]
    var economyModels: [String: String] = [:]
    var tasks: [String: AITaskChoice] = [:]
    var demoMode = false
    /// Provider ids the user has confirmed sending to.
    var consented: [String] = []
    /// Provider ids confirmed with device context included.
    var consentedWithContext: [String] = []

    static let defaultsKey = "assay.ai.settings.v1"

    static func load() -> AIStoredSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let s = try? JSONDecoder().decode(AIStoredSettings.self, from: data) else { return AIStoredSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: AIStoredSettings.defaultsKey) }
    }

    func baseURL(for kind: AIProviderKind) -> String {
        let v = (baseURLs[kind.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? kind.defaultBaseURL : v
    }

    func model(for kind: AIProviderKind) -> String {
        let v = (models[kind.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? kind.defaultModel : v
    }

    func economyModel(for kind: AIProviderKind) -> String {
        let v = (economyModels[kind.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { return v }
        let d = kind.economyModel
        return d.isEmpty ? model(for: kind) : d
    }

    func choice(for task: AITask) -> AITaskChoice {
        tasks[task.rawValue] ?? AITaskChoice(tier: task.defaultTier)
    }

    func model(for kind: AIProviderKind, task: AITask) -> String {
        let c = choice(for: task)
        switch c.tier {
        case .standard: return model(for: kind)
        case .economy: return economyModel(for: kind)
        case .custom:
            let v = c.customModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? model(for: kind) : v
        }
    }

    func resolve(task: AITask) -> AIResolved {
        let p = defaultProvider
        return AIResolved(provider: p, model: model(for: p, task: task), baseURL: baseURL(for: p))
    }

    func hasConsent(_ kind: AIProviderKind, withContext: Bool) -> Bool {
        let base = consented.contains(kind.rawValue)
        return withContext ? (base && consentedWithContext.contains(kind.rawValue)) : base
    }

    func label(for kind: AIProviderKind) -> AIPrivacyLabel {
        AIPrivacyLabel.forProvider(kind, baseURL: baseURL(for: kind))
    }

    /// Minis is a placeholder: only usable once the user has typed a local OpenAI-compatible endpoint.
    func minisHasEndpoint() -> Bool {
        let b = baseURL(for: .minis)
        return AIHost.parse(b) != nil && AIHost.privacyLabel(forBaseURL: b) != .leavesPhone
    }
}
