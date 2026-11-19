import SwiftUI
import Observation

/// State for the Alchemy chat. Advice only: nothing here can reach the device, and the model's text is never executed or parsed into actions.
@Observable
@MainActor
final class AIChatModel {
    var messages: [AIMessage] = []
    var input = ""
    var sending = false
    var errorText: String?
    var includeContext = false
    /// Set when the first-message confirmation sheet must be shown.
    var pending: AIPendingSend?

    private var task: Task<Void, Never>?
    private var pendingUser: AIMessage?

    let ai = AIService.shared

    var canRetry: Bool { errorText != nil && messages.last?.role == .user && !sending }

    var statusLine: String {
        if ai.demoMode { return "Demo replies. Nothing is sent." }
        let kind = ai.defaultProvider
        let s = ai.status(for: kind)
        switch s {
        case .configured: return "\(kind.displayName) · \(ai.settings.model(for: kind, task: .chat))"
        case .needsKey: return "\(kind.displayName) needs a key"
        case .notAvailable(let why): return "\(kind.displayName): \(why)"
        }
    }

    func reset() {
        task?.cancel()
        messages = []
        errorText = nil
        pending = nil
        pendingUser = nil
        sending = false
    }

    func cancelPending() {
        pending = nil
        pendingUser = nil
    }

    // MARK: Sending

    func send(snapshot: DeviceSnapshot?) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        errorText = nil

        if ai.demoMode {
            messages.append(AIMessage(role: .user, content: text, isDemo: true))
            messages.append(AIMessage(role: .assistant, content: AIDemo.reply(to: text), isDemo: true))
            input = ""
            return
        }
        prepare(newUser: AIMessage(role: .user, content: text), snapshot: snapshot)
    }

    func useStarter(_ text: String, snapshot: DeviceSnapshot?) {
        input = text
        send(snapshot: snapshot)
    }

    func retry(snapshot: DeviceSnapshot?) {
        guard canRetry else { return }
        errorText = nil
        prepare(newUser: nil, snapshot: snapshot)
    }

    private func prepare(newUser: AIMessage?, snapshot: DeviceSnapshot?) {
        let kind = ai.defaultProvider
        switch ai.status(for: kind) {
        case .needsKey: errorText = AIError.noKey.errorDescription; return
        case .notAvailable(let why): errorText = why; return
        case .configured: break
        }
        let context = includeContext ? AIPrompts.deviceContext(snapshot: snapshot) : nil
        if includeContext && context == nil {
            errorText = "Device context is on, but no device is connected. Turn it off or connect a device."
            return
        }
        // Demo messages are never sent to a real model.
        var history = messages.filter { !$0.isDemo }
        if let newUser { history.append(newUser) }
        let system = AIPrompts.chatSystem(deviceContext: context)
        let out = AIRedactor.prepare(system: system, messages: history)

        let size = out.system.count + out.messages.reduce(0) { $0 + $1.content.count }
        if size > AIClient.maxPromptCharacters { errorText = AIError.promptTooLarge(size).errorDescription; return }

        let p = AIPendingSend(provider: kind, model: ai.settings.model(for: kind, task: .chat),
                              baseURL: ai.settings.baseURL(for: kind), outgoing: out, withContext: context != nil)
        if ai.needsConsent(provider: kind, withContext: p.withContext) {
            pendingUser = newUser
            pending = p
            return
        }
        run(p, newUser: newUser)
    }

    func confirm() {
        guard let p = pending else { return }
        guard p.provider == ai.defaultProvider, p.baseURL == ai.settings.baseURL(for: p.provider) else {
            cancelPending(); errorText = "Destination changed. Review the message again."; return
        }
        ai.recordConsent(provider: p.provider, withContext: p.withContext)
        let u = pendingUser
        pending = nil
        pendingUser = nil
        run(p, newUser: u)
    }

    private func run(_ p: AIPendingSend, newUser: AIMessage?) {
        if var u = newUser {
            u.redactedCount = p.outgoing.messages.last?.redactedCount ?? 0
            messages.append(u)
            input = ""
        }
        sending = true
        task?.cancel()
        task = Task { [weak self] in
            do {
                let reply = try await AIClient.shared.complete(messages: p.outgoing.messages, system: p.outgoing.system,
                                                               provider: p.provider, model: p.model, maxTokens: 800, baseURL: p.baseURL)
                guard let self else { return }
                self.messages.append(AIMessage(role: .assistant, content: reply.text))
                self.lastReply = reply
                self.sending = false
            } catch is CancellationError {
                self?.sending = false
            } catch let e as AIError {
                self?.errorText = e.errorDescription ?? "The request failed."
                self?.sending = false
            } catch {
                self?.errorText = "The request failed."
                self?.sending = false
            }
        }
    }

    /// Details of the most recent real reply (provider, model, time). Not stored per message.
    var lastReply: AIReply?
}
