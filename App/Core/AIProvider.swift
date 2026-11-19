import Foundation

// MARK: - Wire formats and auth

/// How a provider's HTTP API is shaped.
enum AIWireFormat: Equatable {
    case openAIChat          // POST {base}/chat/completions
    case anthropicMessages   // POST {base}/messages
    case googleGenerate      // POST {base}/models/{model}:generateContent
    case ollamaChat          // POST {base}/api/chat
}

enum AIAuthStyle: Equatable {
    case bearer              // Authorization: Bearer <key>
    case xAPIKey             // x-api-key: <key> (+ anthropic-version)
    case googleKey           // x-goog-api-key: <key>
    case none

    var summary: String {
        switch self {
        case .bearer: return "Authorization header (Bearer)"
        case .xAPIKey: return "x-api-key header"
        case .googleKey: return "x-goog-api-key header"
        case .none: return "No key"
        }
    }
}

// MARK: - Providers

/// Provider-neutral list. Model ids below are starting points only; every one can be changed in settings
/// because providers retire and rename models.
enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case minis, openAI, anthropic, google, openRouter, ollama, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minis: return "Minis"
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google Gemini"
        case .openRouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .custom: return "Custom endpoint"
        }
    }

    /// One line shown under the name in lists.
    var blurb: String {
        switch self {
        case .minis: return "Local endpoint you set yourself"
        case .openAI: return "Chat completions"
        case .anthropic: return "Messages API"
        case .google: return "generateContent"
        case .openRouter: return "OpenAI-compatible router"
        case .ollama: return "Your own server (/api/chat)"
        case .custom: return "Any OpenAI-compatible endpoint"
        }
    }

    var symbol: String {
        switch self {
        case .minis: return "app.connected.to.app.below.fill"
        case .openAI, .anthropic, .google, .openRouter: return "cloud"
        case .ollama: return "server.rack"
        case .custom: return "link"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .minis: return ""
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1beta"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .ollama: return "http://localhost:11434"
        case .custom: return ""
        }
    }

    var wireFormat: AIWireFormat {
        switch self {
        case .minis, .openAI, .openRouter, .custom: return .openAIChat
        case .anthropic: return .anthropicMessages
        case .google: return .googleGenerate
        case .ollama: return .ollamaChat
        }
    }

    var authStyle: AIAuthStyle {
        switch self {
        case .minis, .openAI, .openRouter, .custom: return .bearer
        case .anthropic: return .xAPIKey
        case .google: return .googleKey
        case .ollama: return .none
        }
    }

    /// Starting model for ordinary tasks. Empty means the user must type one.
    var defaultModel: String {
        switch self {
        case .minis, .custom: return ""
        case .openAI: return "gpt-4.1"
        case .anthropic: return "claude-sonnet-4-5"
        case .google: return "gemini-2.5-flash"
        case .openRouter: return "openai/gpt-4.1"
        case .ollama: return "llama3.2"
        }
    }

    /// Cheaper, faster model for small jobs (diagnosis, asset drafts).
    var economyModel: String {
        switch self {
        case .minis, .custom: return ""
        case .openAI: return "gpt-4.1-mini"
        case .anthropic: return "claude-haiku-4-5"
        case .google: return "gemini-2.5-flash-lite"
        case .openRouter: return "openai/gpt-4.1-mini"
        case .ollama: return "llama3.2:1b"
        }
    }

    /// Hosted by someone else regardless of the address typed.
    var isHostedService: Bool {
        switch self {
        case .openAI, .anthropic, .google, .openRouter: return true
        case .minis, .ollama, .custom: return false
        }
    }

    /// Base URL can be changed by the user.
    var baseURLEditable: Bool {
        switch self {
        case .minis, .ollama, .custom: return true
        default: return false
        }
    }

    var usesKeychainKey: Bool { authStyle != .none }

    /// Whether a key is mandatory for this address. Local/LAN endpoints (custom, Minis) may run without one.
    func needsKey(baseURL: String) -> Bool {
        switch self {
        case .openAI, .anthropic, .google, .openRouter: return true
        case .ollama: return false
        case .minis, .custom: return AIHost.privacyLabel(forBaseURL: baseURL) == .leavesPhone
        }
    }
}

// MARK: - Tasks and per-task model choice

enum AITask: String, CaseIterable, Identifiable, Codable {
    case diagnose, tweakHelp, assetDrafts, chat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .diagnose: return "Diagnose"
        case .tweakHelp: return "Tweak help"
        case .assetDrafts: return "Asset drafts"
        case .chat: return "Alchemy chat"
        }
    }

    var detail: String {
        switch self {
        case .diagnose: return "Match a symptom to the known list"
        case .tweakHelp: return "Explain what a tweak does"
        case .assetDrafts: return "Draft names and descriptions"
        case .chat: return "Free-form questions"
        }
    }

    var defaultTier: AIModelTier {
        switch self {
        case .diagnose, .assetDrafts: return .economy
        case .tweakHelp, .chat: return .standard
        }
    }
}

enum AIModelTier: String, CaseIterable, Identifiable, Codable {
    case standard, economy, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "Standard model"
        case .economy: return "Economy model"
        case .custom: return "Custom model id"
        }
    }
}

struct AITaskChoice: Codable, Equatable {
    var tier: AIModelTier
    var customModel: String = ""
}

// MARK: - Messages

enum AIRole: String, Codable { case user, assistant }

struct AIMessage: Identifiable, Equatable {
    let id: UUID
    var role: AIRole
    var content: String
    /// True for canned demo replies. Always shown with a Demo tag.
    var isDemo: Bool
    /// Items removed from this message before sending.
    var redactedCount: Int

    init(role: AIRole, content: String, isDemo: Bool = false, redactedCount: Int = 0) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.isDemo = isDemo
        self.redactedCount = redactedCount
    }
}

struct AIReply: Equatable {
    var text: String
    var provider: AIProviderKind
    var model: String
    var latency: TimeInterval
    var inputTokens: Int?
    var outputTokens: Int?
    var isDemo: Bool = false
}

/// What is about to leave the app: shown in the confirmation sheet, then sent as-is.
struct AIOutgoing: Equatable {
    var system: String
    var messages: [AIMessage]
    var redactedCount: Int
    var categories: [String]
}

// MARK: - Errors (plain English; never contain keys or response bodies)

enum AIError: LocalizedError {
    case noKey
    case invalidKey
    case network(local: Bool)
    case timeout(seconds: Int)
    case modelNotFound
    case modelMissing
    case rateLimit
    case quota
    case serverBusy(Int)
    case badAddress
    case insecureEndpoint
    case promptTooLarge(Int)
    case emptyPrompt
    case consentRequired(String)
    case notAvailable(String)
    case emptyReply
    case malformed
    case blocked
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .noKey:
            return "No API key is saved for this provider. Add one in AI settings."
        case .invalidKey:
            return "Invalid key: the provider refused it. Check it was copied in full and is still active."
        case .network(let local):
            return local
                ? "Network problem: could not reach that address. Check the server is running, and that Local Network is allowed for Assay in Settings."
                : "Network problem: could not reach the provider. Check your connection and try again."
        case .timeout(let s):
            return "Network problem: no answer within \(s) seconds."
        case .modelNotFound:
            return "Model not found. Check the model name in AI settings."
        case .modelMissing:
            return "No model is set. Add a model name in AI settings."
        case .rateLimit:
            return "Rate limit reached. Wait a minute and try again."
        case .quota:
            return "The account has no credit or quota left. Check billing with the provider."
        case .serverBusy(let c):
            return "The provider is busy or having trouble (code \(c)). Try again shortly."
        case .badAddress:
            return "Nothing was found at that address. Check the base URL in AI settings."
        case .insecureEndpoint:
            return "Refused: this address is not encrypted (http) and is not on your phone or LAN, so no key or text was sent."
        case .promptTooLarge(let n):
            return "That is too long to send (\(n) characters; the limit is \(AIClient.maxPromptCharacters)). Shorten it or start a new chat."
        case .emptyPrompt:
            return "There is nothing to send."
        case .consentRequired(let p):
            return "Confirm what will be sent to \(p) first."
        case .notAvailable(let why):
            return why
        case .emptyReply:
            return "The provider answered with no text. Try again or choose another model."
        case .malformed:
            return "The provider's answer was not in the expected format."
        case .blocked:
            return "The provider declined to answer this request."
        case .rejected(let c):
            return "The provider rejected the request (code \(c)). Check the model name and base URL."
        }
    }
}

struct AITestResult: Equatable {
    var ok: Bool
    var latencyMS: Int?
    var message: String
}
