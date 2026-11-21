import SwiftUI

// MARK: - Provider list

struct AISettingsView: View {
    @Environment(\.theme) private var t
    private var ai: AIService { AIService.shared }

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(get: { ai.demoMode }, set: { ai.demoMode = $0 })) {
                    HStack(spacing: 8) { Text("Demo"); Tag(style: .experimental, text: "Demo") }
                }
                Text("Demo answers with canned, clearly labelled sample replies. No key needed and nothing is sent.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            } footer: {
                Text("AI is optional. Assay works without it.")
            }.rowCard()

            Section {
                ForEach(AIProviderKind.allCases) { kind in
                    NavigationLink { AIProviderDetailView(kind: kind) } label: { AIProviderRow(kind: kind) }
                }
            } header: { Text("Providers") } footer: {
                Text("Keys are kept in the iOS Keychain on this phone only, and are shown as the last four characters.")
            }.rowCard()

            Section {
                Picker("Default provider", selection: Binding(get: { ai.settings.defaultProvider }, set: { ai.settings.defaultProvider = $0 })) {
                    ForEach(AIProviderKind.allCases) { k in Text(k.displayName).tag(k) }
                }
                let d = ai.settings.defaultProvider
                let st = ai.status(for: d)
                LabeledContent("Status") { Tag(style: st.tagStyle, text: st.title) }
                if let detail = st.detail { Text(detail).font(.system(size: 12.5)).foregroundStyle(t.ink3) }
                LabeledContent("Privacy") { Text(ai.privacyLabel(for: d).title).foregroundStyle(t.ink2) }
            } header: { Text("Default") }.rowCard()

            Section {
                ForEach(AITask.allCases) { task in AITaskRow(task: task) }
            } header: { Text("Model per task") } footer: {
                Text("Economy models are cheaper and quicker. Diagnose and asset drafts use them by default.")
            }.rowCard()

            Section {
                Text("What is sent: only the text you see in the confirmation sheet. Assay removes UDID-, serial-, ECID- and key-like strings first, and never includes your UDID, serial number or pairing data.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }.rowCard()
        }
        .themedList()
        .navigationTitle("AI settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AIProviderRow: View {
    @Environment(\.theme) private var t
    let kind: AIProviderKind
    private var ai: AIService { AIService.shared }

    var body: some View {
        let status = ai.status(for: kind)
        let label = ai.privacyLabel(for: kind)
        HStack(spacing: 12) {
            Image(systemName: kind.symbol).frame(width: 24).foregroundStyle(t.ink2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kind.displayName).foregroundStyle(t.ink)
                    if ai.settings.defaultProvider == kind { Text("Default").font(.system(size: 11.5)).foregroundStyle(t.ink3) }
                }
                Text(status.detail ?? label.title).font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }
            Spacer(minLength: 8)
            Tag(style: status.tagStyle, text: status.title)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AITaskRow: View {
    @Environment(\.theme) private var t
    let task: AITask
    private var ai: AIService { AIService.shared }

    var body: some View {
        let choice = ai.settings.choice(for: task)
        let kind = ai.settings.defaultProvider
        let model = ai.settings.model(for: kind, task: task)
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title).foregroundStyle(t.ink)
            Text(task.detail).font(.system(size: 12.5)).foregroundStyle(t.ink3)
            Picker(task.title, selection: Binding(
                get: { ai.settings.choice(for: task).tier },
                set: { v in var c = ai.settings.choice(for: task); c.tier = v; ai.settings.tasks[task.rawValue] = c })) {
                ForEach(AIModelTier.allCases) { tier in Text(tier.title).tag(tier) }
            }
            .pickerStyle(.menu)
            if choice.tier == .custom {
                TextField("Model id", text: Binding(
                    get: { ai.settings.choice(for: task).customModel },
                    set: { v in var c = ai.settings.choice(for: task); c.customModel = v; ai.settings.tasks[task.rawValue] = c }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Text(model.isEmpty ? "Uses: not set for \(kind.displayName)" : "Uses: \(model)")
                .font(.system(size: 12.5)).foregroundStyle(t.ink2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - One provider

struct AIProviderDetailView: View {
    @Environment(\.theme) private var t
    let kind: AIProviderKind
    private var ai: AIService { AIService.shared }

    @State private var keyDraft = ""
    @State private var keyError: String?
    @State private var testing = false
    @State private var testResult: AITestResult?
    @State private var confirmDelete = false

    var body: some View {
        let status = ai.status(for: kind)
        let label = ai.privacyLabel(for: kind)
        List {
            Section {
                LabeledContent("Status") { Tag(style: status.tagStyle, text: status.title) }
                if let d = status.detail { Text(d).font(.system(size: 13)).foregroundStyle(t.ink2) }
                HStack(spacing: 8) {
                    Image(systemName: label.symbol).foregroundStyle(t.ink2)
                    Text(label.title).foregroundStyle(t.ink)
                }
                Text(label.detail).font(.system(size: 12.5)).foregroundStyle(t.ink3)
                LabeledContent("API") { Text(kind.authStyle.summary).foregroundStyle(t.ink2) }
            } footer: {
                if kind == .minis {
                    Text("Use Analyse with Minis for the native report handoff. No API key is needed. The optional local chat endpoint below is separate; it does not connect to your Minis account.")
                }
            }.rowCard()

            if kind == .minis { Section { NavigationLink("Analyse with Minis") { MinisReviewView() } }.rowCard() }
            if kind.usesKeychainKey { keySection }
            if kind.baseURLEditable || kind == .custom { endpointSection }
            modelSection
            if status.isReady || kind.isHostedService { testSection(status: status) }
            if ai.settings.hasConsent(kind, withContext: false) {
                Section {
                    Button("Ask me again before sending") { ai.revokeConsent(for: kind) }
                } footer: { Text("You confirmed sending to \(kind.displayName). This asks again on the next message.") }.rowCard()
            }
        }
        .themedList()
        .navigationTitle(kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete the saved key?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete key", role: .destructive) { ai.deleteKey(for: kind); testResult = nil }
        }
    }

    // MARK: Key

    private var keySection: some View {
        Section {
            if let masked = ai.maskedKey(for: kind) {
                LabeledContent("Saved key") { Text(masked).font(.system(.body, design: .monospaced)).foregroundStyle(t.ink2) }
            } else {
                LabeledContent("Saved key") { Text(kind.needsKey(baseURL: ai.settings.baseURL(for: kind)) ? "None" : "None (optional)").foregroundStyle(t.ink3) }
            }
            SecureField(AIKeychain.has(for: kind) ? "Paste a new key to replace it" : "Paste API key", text: $keyDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if let e = keyError { Text(e).font(.system(size: 12.5)).foregroundStyle(t.ink2) }
            Button("Save key") { saveKey() }.disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if AIKeychain.has(for: kind) {
                Button("Delete key", role: .destructive) { confirmDelete = true }
            }
        } header: { Text("API key") } footer: {
            Text("Stored only in the iOS Keychain on this phone (this device only, after first unlock). Never put in settings, URLs, prompts or logs.")
        }.rowCard()
    }

    private func saveKey() {
        do {
            try ai.saveKey(keyDraft, for: kind)
            keyDraft = ""
            keyError = nil
            testResult = nil
        } catch {
            keyError = (error as? LocalizedError)?.errorDescription ?? "The key could not be saved."
        }
    }

    // MARK: Endpoint and model

    private var endpointSection: some View {
        Section {
            TextField(kind == .ollama ? "http://192.168.1.20:11434" : "https://example.com/v1", text: Binding(
                get: { ai.settings.baseURLs[kind.rawValue] ?? "" },
                set: { ai.settings.baseURLs[kind.rawValue] = $0 }))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            let current = ai.settings.baseURL(for: kind)
            if current.isEmpty {
                Text("Not set.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
            } else if AIHost.parse(current) == nil {
                Text("Not a valid address. Start with http:// or https://.").font(.system(size: 12.5)).foregroundStyle(t.ink2)
            } else {
                Text("Requests go to \(current). Classified as: \(AIHost.privacyLabel(forBaseURL: current).title).")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }
            if kind.defaultBaseURL.isEmpty == false, (ai.settings.baseURLs[kind.rawValue] ?? "").isEmpty == false {
                Button("Use default (\(kind.defaultBaseURL))") { ai.settings.baseURLs[kind.rawValue] = nil }
            }
        } header: { Text("Base URL") } footer: {
            switch kind {
            case .ollama: Text("Use localhost for Ollama on this phone, or a LAN address such as http://192.168.1.20:11434 for a computer on your network. iOS asks for Local Network access the first time. Unencrypted http is only allowed for localhost, private addresses and .local names.")
            case .minis: Text("A local OpenAI-compatible endpoint, for example http://localhost:1234/v1. Public addresses are not accepted here.")
            default: Text("Any OpenAI-compatible endpoint. Assay adds /chat/completions. Public addresses must use https.")
            }
        }.rowCard()
    }

    private var modelSection: some View {
        Section {
            TextField(kind.defaultModel.isEmpty ? "Model id" : kind.defaultModel, text: Binding(
                get: { ai.settings.models[kind.rawValue] ?? "" },
                set: { ai.settings.models[kind.rawValue] = $0 }))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField(kind.economyModel.isEmpty ? "Economy model id (optional)" : kind.economyModel, text: Binding(
                get: { ai.settings.economyModels[kind.rawValue] ?? "" },
                set: { ai.settings.economyModels[kind.rawValue] = $0 }))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            LabeledContent("Standard") { Text(ai.settings.model(for: kind).isEmpty ? "Not set" : ai.settings.model(for: kind)).foregroundStyle(t.ink2) }
            LabeledContent("Economy") { Text(ai.settings.economyModel(for: kind).isEmpty ? "Not set" : ai.settings.economyModel(for: kind)).foregroundStyle(t.ink2) }
        } header: { Text("Models") } footer: {
            Text("Leave blank to use the suggested ids. Providers rename and retire models, so change these if a test says the model was not found.")
        }.rowCard()
    }

    // MARK: Test

    private func testSection(status: AIProviderStatus) -> some View {
        Section {
            Button {
                run()
            } label: {
                HStack { Text("Test connection"); Spacer(); if testing { ProgressView() } }
            }
            .disabled(testing || !status.isReady)
            if let r = testResult {
                HStack(alignment: .top, spacing: 8) {
                    Tag(style: r.ok ? .reversible : .caution, text: r.ok ? "Connected" : "Failed")
                    Text(r.message).font(.system(size: 13)).foregroundStyle(t.ink2)
                }
            }
        } footer: {
            Text("Sends one tiny request (“Reply with the single word OK”) with a 10 second limit. None of your messages or device facts are included.")
        }.rowCard()
    }

    private func run() {
        testing = true
        testResult = nil
        Task {
            let r = await ai.test(kind)
            testResult = r
            testing = false
        }
    }
}
