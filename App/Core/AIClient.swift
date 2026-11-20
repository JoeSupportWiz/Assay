import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Refuses every redirect, so a key can never be forwarded to another host.
private final class AINoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// One method, four wire formats. Non-streaming. Keys are read from the Keychain at the moment of the request
/// and only ever placed in an HTTP header; they are never logged, returned or stored.
actor AIClient {
    static let shared = AIClient()

    static let maxPromptCharacters = 60_000
    static let requestTimeout: TimeInterval = 60
    static let testTimeout: TimeInterval = 10
    static let anthropicVersion = "2023-06-01"

    private let session: URLSession
    private let redirectGuard = AINoRedirectDelegate()

    init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = AIClient.requestTimeout
        c.timeoutIntervalForResource = AIClient.requestTimeout
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: c)
    }

    // MARK: Public API

    /// Sends the conversation and returns the model's reply. `baseURL` defaults to the saved setting for the provider.
    /// Hosted sends recheck the saved endpoint consent, including device context when supplied.
    func complete(messages: [AIMessage], system: String?, provider: AIProviderKind, model: String,
                  maxTokens: Int, baseURL: String? = nil, withContext: Bool) async throws -> AIReply {
        let reply = try await exchange(messages: messages, system: system, provider: provider, model: model,
                                       maxTokens: maxTokens, baseURL: baseURL, purpose: .conversation(withContext: withContext), timeout: AIClient.requestTimeout)
        if reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw AIError.emptyReply }
        return reply
    }

    /// One tiny request with a 10 second timeout. The message never contains the key or any response body.
    func test(provider: AIProviderKind, model: String, baseURL: String? = nil) async -> AITestResult {
        let ping = [AIMessage(role: .user, content: "Reply with the single word OK.")]
        do {
            let r = try await exchange(messages: ping, system: nil, provider: provider, model: model, maxTokens: 16,
                                       baseURL: baseURL, purpose: .connectionTest, timeout: AIClient.testTimeout)
            let ms = Int((r.latency * 1000).rounded())
            return AITestResult(ok: true, latencyMS: ms, message: "Connected in \(ms) ms.")
        } catch let e as AIError {
            return AITestResult(ok: false, latencyMS: nil, message: e.errorDescription ?? "The test failed.")
        } catch {
            return AITestResult(ok: false, latencyMS: nil, message: "The test failed.")
        }
    }

    // MARK: Core

    private enum Purpose { case conversation(withContext: Bool), connectionTest }

    private func exchange(messages: [AIMessage], system: String?, provider: AIProviderKind, model rawModel: String,
                          maxTokens: Int, baseURL override: String?, purpose: Purpose, timeout: TimeInterval) async throws -> AIReply {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let settings = AIStoredSettings.load()

        // Resolve and vet the address.
        let base = (override ?? settings.baseURL(for: provider)).trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .minis && !settings.minisHasEndpoint() && override == nil {
            throw AIError.notAvailable("Not available from inside this app yet. Add a local OpenAI-compatible endpoint under Minis in AI settings to use it.")
        }
        let endpoint = try AIHost.endpoint(provider: provider, base: base)
        if case .conversation(let withContext) = purpose, endpoint.label.needsConsent {
            guard base == settings.baseURL(for: provider), settings.hasConsent(provider, withContext: withContext) else {
                throw AIError.consentRequired(provider.displayName)
            }
        }
        if model.isEmpty { throw AIError.modelMissing }

        // Size and content checks.
        let trimmed = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if trimmed.isEmpty { throw AIError.emptyPrompt }
        let size = (system ?? "").count + trimmed.reduce(0) { $0 + $1.content.count }
        if size > AIClient.maxPromptCharacters { throw AIError.promptTooLarge(size) }

        // Key (read late, used only in a header).
        let key = provider.usesKeychainKey ? AIKeychain.read(for: provider, endpoint: base) : nil
        if key != nil && endpoint.url.scheme?.lowercased() != "https" { throw AIError.insecureEndpoint }
        if provider.needsKey(baseURL: base) && key == nil { throw AIError.noKey }

        let request = try AIClient.buildRequest(provider: provider, baseURL: endpoint.url, model: model, messages: trimmed,
                                                system: system, maxTokens: maxTokens, key: key, timeout: timeout)
        let local = endpoint.label != .leavesPhone
        let started = Date()
        let data: Data
        let status: Int
        do {
            let (d, response) = try await session.data(for: request, delegate: redirectGuard)
            data = d
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch let e as URLError {
            switch e.code {
            case .timedOut: throw AIError.timeout(seconds: Int(timeout))
            case .cancelled: throw CancellationError()
            default: throw AIError.network(local: local)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIError.network(local: local)
        }
        let latency = Date().timeIntervalSince(started)

        guard (200...299).contains(status) else { throw AIClient.mapStatus(status, body: data, provider: provider) }
        let parsed = try AIClient.parse(provider.wireFormat, data: data)
        return AIReply(text: parsed.text, provider: provider, model: model, latency: latency,
                       inputTokens: parsed.input, outputTokens: parsed.output)
    }

    // MARK: Request building (static, so it can be unit-tested without the network)

    static func buildRequest(provider: AIProviderKind, baseURL: URL, model: String, messages: [AIMessage],
                             system: String?, maxTokens: Int, key: String?, timeout: TimeInterval) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw AIError.badAddress }
        let cap = max(1, min(maxTokens, 8_192))
        let sys = (system ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        var path = ""
        var body: [String: Any] = [:]
        var headers: [String: String] = ["Content-Type": "application/json", "Accept": "application/json"]

        switch provider.wireFormat {
        case .openAIChat:
            path = "/chat/completions"
            var msgs: [[String: String]] = []
            if !sys.isEmpty { msgs.append(["role": "system", "content": sys]) }
            for m in messages { msgs.append(["role": m.role.rawValue, "content": m.content]) }
            body = ["model": model, "messages": msgs]
            // OpenAI's current models reject max_tokens; other OpenAI-compatible servers still expect it.
            body[provider == .openAI ? "max_completion_tokens" : "max_tokens"] = cap
            if let key, !key.isEmpty { headers["Authorization"] = "Bearer " + key }

        case .anthropicMessages:
            path = "/messages"
            // The API wants strictly alternating turns that start with the user.
            var turns: [[String: String]] = []
            for m in messages {
                if let last = turns.last, last["role"] == m.role.rawValue {
                    turns[turns.count - 1]["content"] = (last["content"] ?? "") + "\n\n" + m.content
                } else {
                    turns.append(["role": m.role.rawValue, "content": m.content])
                }
            }
            if turns.first?["role"] == "assistant" { turns.insert(["role": "user", "content": "(conversation continues)"], at: 0) }
            body = ["model": model, "max_tokens": cap, "messages": turns]
            if !sys.isEmpty { body["system"] = sys }
            headers["anthropic-version"] = anthropicVersion
            if let key, !key.isEmpty { headers["x-api-key"] = key }

        case .googleGenerate:
            var name = model
            if name.hasPrefix("models/") { name = String(name.dropFirst(7)) }
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            path = "/models/" + encoded + ":generateContent"
            var contents: [[String: Any]] = []
            for m in messages {
                let role = m.role == .assistant ? "model" : "user"
                if let last = contents.last, last["role"] as? String == role,
                   var parts = last["parts"] as? [[String: String]] {
                    parts.append(["text": m.content])
                    contents[contents.count - 1]["parts"] = parts
                } else {
                    contents.append(["role": role, "parts": [["text": m.content]]])
                }
            }
            body = ["contents": contents, "generationConfig": ["maxOutputTokens": cap]]
            if !sys.isEmpty { body["systemInstruction"] = ["parts": [["text": sys]]] }
            if let key, !key.isEmpty { headers["x-goog-api-key"] = key }

        case .ollamaChat:
            path = "/api/chat"
            var msgs: [[String: String]] = []
            if !sys.isEmpty { msgs.append(["role": "system", "content": sys]) }
            for m in messages { msgs.append(["role": m.role.rawValue, "content": m.content]) }
            body = ["model": model, "messages": msgs, "stream": false, "options": ["num_predict": cap]]
        }

        var prefix = components.percentEncodedPath
        while prefix.hasSuffix("/") { prefix.removeLast() }
        components.percentEncodedPath = prefix + path
        guard let url = components.url else { throw AIError.badAddress }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        req.httpMethod = "POST"
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { throw AIError.malformed }
        req.httpBody = data
        return req
    }

    // MARK: Responses

    struct Parsed { var text: String; var input: Int?; var output: Int? }

    static func parse(_ format: AIWireFormat, data: Data) throws -> Parsed {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw AIError.malformed }
        switch format {
        case .openAIChat:
            let usage = obj["usage"] as? [String: Any]
            guard let choices = obj["choices"] as? [[String: Any]], let first = choices.first else { throw AIError.malformed }
            if let message = first["message"] as? [String: Any] {
                if let s = message["content"] as? String {
                    return Parsed(text: s, input: usage?["prompt_tokens"] as? Int, output: usage?["completion_tokens"] as? Int)
                }
                if let parts = message["content"] as? [[String: Any]] {
                    let s = parts.compactMap { $0["text"] as? String }.joined()
                    return Parsed(text: s, input: usage?["prompt_tokens"] as? Int, output: usage?["completion_tokens"] as? Int)
                }
                if message["refusal"] is String { throw AIError.blocked }
                return Parsed(text: "", input: usage?["prompt_tokens"] as? Int, output: usage?["completion_tokens"] as? Int)
            }
            throw AIError.malformed

        case .anthropicMessages:
            guard let blocks = obj["content"] as? [[String: Any]] else { throw AIError.malformed }
            let text = blocks.compactMap { b -> String? in (b["type"] as? String) == "text" ? b["text"] as? String : nil }.joined()
            let usage = obj["usage"] as? [String: Any]
            if text.isEmpty, (obj["stop_reason"] as? String) == "refusal" { throw AIError.blocked }
            return Parsed(text: text, input: usage?["input_tokens"] as? Int, output: usage?["output_tokens"] as? Int)

        case .googleGenerate:
            let usage = obj["usageMetadata"] as? [String: Any]
            let tokensIn = usage?["promptTokenCount"] as? Int
            let tokensOut = usage?["candidatesTokenCount"] as? Int
            guard let candidates = obj["candidates"] as? [[String: Any]], let first = candidates.first else {
                if (obj["promptFeedback"] as? [String: Any])?["blockReason"] != nil { throw AIError.blocked }
                throw AIError.malformed
            }
            if let content = first["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]] {
                let text = parts.compactMap { $0["text"] as? String }.joined()
                return Parsed(text: text, input: tokensIn, output: tokensOut)
            }
            if (first["finishReason"] as? String) == "SAFETY" { throw AIError.blocked }
            return Parsed(text: "", input: tokensIn, output: tokensOut)

        case .ollamaChat:
            guard let message = obj["message"] as? [String: Any], let s = message["content"] as? String else { throw AIError.malformed }
            return Parsed(text: s, input: obj["prompt_eval_count"] as? Int, output: obj["eval_count"] as? Int)
        }
    }

    /// Classifies a failed response using the status code and, locally, a lowercase peek at the error text.
    /// The body is never returned, logged or shown.
    static func mapStatus(_ status: Int, body: Data, provider: AIProviderKind) -> AIError {
        let text = errorText(body)
        switch status {
        case 401, 403:
            return .invalidKey
        case 402:
            return .quota
        case 404:
            if text.contains("model") { return .modelNotFound }
            return provider == .ollama ? .modelNotFound : .badAddress
        case 400:
            if text.contains("api key") || text.contains("api_key") || text.contains("apikey") { return .invalidKey }
            if text.contains("model") && (text.contains("not found") || text.contains("does not exist") || text.contains("not supported") || text.contains("invalid")) {
                return .modelNotFound
            }
            return .rejected(status)
        case 408:
            return .timeout(seconds: Int(requestTimeout))
        case 429:
            if text.contains("quota") || text.contains("billing") || text.contains("credit") { return .quota }
            return .rateLimit
        case 500...599:
            return .serverBusy(status)
        case 0:
            return .malformed
        default:
            return .rejected(status)
        }
    }

    private static func errorText(_ data: Data) -> String {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return "" }
        var parts: [String] = []
        if let e = obj["error"] as? [String: Any] {
            for k in ["message", "code", "type", "status"] { if let s = e[k] as? String { parts.append(s) } }
        } else if let s = obj["error"] as? String {
            parts.append(s)
        }
        if let s = obj["message"] as? String { parts.append(s) }
        return String(parts.joined(separator: " ").lowercased().prefix(400))
    }
}
