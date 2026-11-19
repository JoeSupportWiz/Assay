import SwiftUI
import Observation

// MARK: - Status

enum AIProviderStatus: Equatable {
    case configured
    case needsKey
    case notAvailable(String)

    var title: String {
        switch self {
        case .configured: return "Configured"
        case .needsKey: return "Needs key"
        case .notAvailable: return "Not available"
        }
    }

    var detail: String? {
        if case .notAvailable(let why) = self { return why }
        return nil
    }

    var isReady: Bool { self == .configured }

    var tagStyle: TagStyle {
        switch self {
        case .configured: return .reversible
        case .needsKey: return .caution
        case .notAvailable: return .unknown
        }
    }
}

// MARK: - Prompts (the exact text shown in the "System prompt" disclosure is the text that is sent)

enum AIPrompts {
    static let chatSystem = """
    You are Alchemy, the help assistant inside Assay, an iPhone app for inspecting a device and reviewing small settings changes. \
    You give advice only. You cannot read, change or fix anything on the device, and you must never say or imply that you have. \
    When a change might help, explain what to look at and say that the user decides in Assay's own review screen, where every change is previewed and can be undone. \
    Be honest about uncertainty and say when you do not know. Do not ask for, repeat or guess identifiers such as a UDID, serial number, ECID or pairing data, and do not ask for API keys or passwords. \
    Use UK English. Keep answers short and plain.
    """

    static func chatSystem(deviceContext: String?) -> String {
        guard let ctx = deviceContext, !ctx.isEmpty else { return chatSystem }
        return chatSystem + "\n\n" + ctx
    }

    /// Model and iOS version only. Never the device name, UDID, serial, ECID or any other fact.
    static func deviceContext(snapshot: DeviceSnapshot?) -> String? {
        guard let s = snapshot else { return nil }
        var lines = ["Device context supplied by the user:", "- Model: \(s.model)", "- iOS: \(s.osVersion)"]
        if s.isDemo { lines.append("- Note: this is a demonstration device, not a real one.") }
        return lines.joined(separator: "\n")
    }

    static let starters: [String] = [
        "Why is my clock stuck at 9:41?",
        "There is a green line across my Lock Screen. What is it?",
        "White dots follow my finger. How do I get rid of them?",
        "My backups keep stalling. What usually causes that?"
    ]
}

// MARK: - Demo replies

enum AIDemo {
    static let label = "Demo reply: sample text from Assay's built-in knowledge list. No AI model was contacted."

    /// Canned, clearly labelled. Uses Knowledge.symptoms so the sample is at least accurate to what Assay knows.
    static func reply(to text: String) -> String {
        if let (symptom, _) = Knowledge.match(text).first {
            var s = label + "\n\n" + symptom.title + ": " + symptom.cause
            if symptom.culprit != nil {
                s += "\n\nAssay can show you a fix for this in Diagnose. You would review it, apply it and could undo it. I cannot change anything myself."
            } else {
                s += "\n\nThere is no settings change for this one, so it is advice only."
            }
            return s
        }
        return label + "\n\nI do not recognise that from Assay's list of known symptoms. In a real reply I would ask what you see, when it started and what you changed just before. I cannot change anything on your device."
    }
}

// MARK: - Service

/// App-wide AI settings and key state. Settings are saved to UserDefaults (never keys). Keys live in AIKeychain.
@Observable
@MainActor
final class AIService {
    static let shared = AIService()

    var settings: AIStoredSettings { didSet { settings.save() } }
    /// Bumped when a key is saved or deleted so views re-read Keychain presence.
    private(set) var keyRevision = 0

    init() {
        settings = AIStoredSettings.load()
        if ProcessInfo.processInfo.arguments.contains("-uiDemo") { settings.demoMode = true }
    }

    // MARK: Status

    func status(for kind: AIProviderKind) -> AIProviderStatus {
        _ = keyRevision
        let base = settings.baseURL(for: kind)
        switch kind {
        case .minis:
            if !settings.minisHasEndpoint() { return .notAvailable("Not available from inside this app yet") }
            if settings.model(for: kind).isEmpty { return .notAvailable("Add a model name") }
            return .configured
        case .custom:
            if base.isEmpty { return .notAvailable("Add a base URL") }
            if AIHost.parse(base) == nil { return .notAvailable("That base URL is not valid") }
            if settings.model(for: kind).isEmpty { return .notAvailable("Add a model name") }
            if kind.needsKey(baseURL: base) && !AIKeychain.has(for: kind) { return .needsKey }
            return .configured
        case .ollama:
            if AIHost.parse(base) == nil { return .notAvailable("That base URL is not valid") }
            if settings.model(for: kind).isEmpty { return .notAvailable("Add a model name") }
            return .configured
        case .openAI, .anthropic, .google, .openRouter:
            if settings.model(for: kind).isEmpty { return .notAvailable("Add a model name") }
            return AIKeychain.has(for: kind) ? .configured : .needsKey
        }
    }

    func privacyLabel(for kind: AIProviderKind) -> AIPrivacyLabel { settings.label(for: kind) }

    var defaultProvider: AIProviderKind { settings.defaultProvider }
    var demoMode: Bool {
        get { settings.demoMode }
        set { settings.demoMode = newValue }
    }

    /// Ready to send for real (ignores demo mode).
    var liveReady: Bool { status(for: settings.defaultProvider).isReady }

    // MARK: Keys

    func saveKey(_ raw: String, for kind: AIProviderKind) throws {
        try AIKeychain.save(raw, for: kind)
        keyRevision += 1
    }

    func deleteKey(for kind: AIProviderKind) {
        AIKeychain.delete(for: kind)
        // Forget consent too: a new key is a new account.
        settings.consented.removeAll { $0 == kind.rawValue }
        settings.consentedWithContext.removeAll { $0 == kind.rawValue }
        keyRevision += 1
    }

    func maskedKey(for kind: AIProviderKind) -> String? {
        _ = keyRevision
        return AIKeychain.masked(for: kind)
    }

    // MARK: Consent

    func needsConsent(provider kind: AIProviderKind, withContext: Bool) -> Bool {
        guard settings.label(for: kind).needsConsent else { return false }
        return !settings.hasConsent(kind, withContext: withContext)
    }

    func recordConsent(provider kind: AIProviderKind, withContext: Bool) {
        if !settings.consented.contains(kind.rawValue) { settings.consented.append(kind.rawValue) }
        if withContext && !settings.consentedWithContext.contains(kind.rawValue) { settings.consentedWithContext.append(kind.rawValue) }
    }

    func revokeConsent(for kind: AIProviderKind) {
        settings.consented.removeAll { $0 == kind.rawValue }
        settings.consentedWithContext.removeAll { $0 == kind.rawValue }
    }

    // MARK: Test

    func test(_ kind: AIProviderKind) async -> AITestResult {
        let s = settings
        return await AIClient.shared.test(provider: kind, model: s.model(for: kind), baseURL: s.baseURL(for: kind))
    }
}
