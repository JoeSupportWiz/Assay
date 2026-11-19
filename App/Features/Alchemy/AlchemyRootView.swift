import SwiftUI

/// Alchemy: a plain advice chat. It cannot change the device. Place inside a NavigationStack.
struct AlchemyRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    @State private var chat = AIChatModel()
    @State private var showPrompt = false
    @FocusState private var inputFocused: Bool

    private var ai: AIService { chat.ai }
    private var snapshot: DeviceSnapshot? { model.snapshot }
    private var provider: AIProviderKind { ai.defaultProvider }

    var body: some View {
        List {
            introSection
            if chat.messages.isEmpty { startersSection }
            if !chat.messages.isEmpty || chat.sending || chat.errorText != nil { conversationSection }
        }
        .themedList()
        .navigationTitle("Alchemy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { AISettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("AI settings")
            }
            ToolbarItem(placement: .topBarLeading) {
                if !chat.messages.isEmpty {
                    Button("New chat") { chat.reset() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .sheet(item: $chat.pending) { p in
            AIConsentSheet(pending: p, onConfirm: { chat.confirm() }, onCancel: { chat.cancelPending() })
        }
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised").foregroundStyle(t.ink).padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI proposes, you approve").font(.system(size: 15, weight: .semibold)).foregroundStyle(t.ink)
                    Text("Replies are advice only. This chat cannot read or change your device. Any change you choose to make goes through Assay's own review screen, where you can preview, apply and undo it.")
                        .font(.system(size: 13)).foregroundStyle(t.ink2)
                }
            }
            .accessibilityElement(children: .combine)

            Toggle(isOn: Binding(get: { ai.demoMode }, set: { ai.demoMode = $0 })) {
                HStack(spacing: 8) { Text("Demo"); Tag(style: .experimental, text: "Demo") }
            }
            if ai.demoMode {
                Text("Replies are canned samples from Assay's own symptom list. No AI model is contacted and no key is needed.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            } else {
                providerStatusRow
            }

            Toggle("Device context", isOn: $chat.includeContext)
            if chat.includeContext {
                if let ctx = AIPrompts.deviceContext(snapshot: snapshot) {
                    Text(ctx).font(.system(size: 12.5)).foregroundStyle(t.ink2)
                    Text("Model and iOS version only. Never the UDID, serial number or ECID.")
                        .font(.system(size: 12.5)).foregroundStyle(t.ink3)
                } else {
                    Text("Not available: no device is connected.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
                }
            } else {
                Text("Off. Nothing about your device is added to your questions.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }

            DisclosureGroup("System prompt", isExpanded: $showPrompt) {
                Text(AIPrompts.chatSystem(deviceContext: chat.includeContext ? AIPrompts.deviceContext(snapshot: snapshot) : nil))
                    .font(.system(size: 12.5)).foregroundStyle(t.ink2).textSelection(.enabled)
                    .padding(.top, 4)
            }
        }.rowCard()
    }

    private var providerStatusRow: some View {
        let status = ai.status(for: provider)
        let label = ai.privacyLabel(for: provider)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(provider.displayName).foregroundStyle(t.ink)
                Spacer()
                Tag(style: status.tagStyle, text: status.title)
            }
            HStack(spacing: 6) {
                Image(systemName: label.symbol).font(.system(size: 12)).foregroundStyle(t.ink2)
                Text(label.title).font(.system(size: 13)).foregroundStyle(t.ink2)
            }
            if let d = status.detail { Text(d).font(.system(size: 12.5)).foregroundStyle(t.ink3) }
            if status == .needsKey || status.detail != nil {
                NavigationLink("Open AI settings") { AISettingsView() }.font(.system(size: 14))
            }
        }
    }

    private var startersSection: some View {
        Section {
            ForEach(AIPrompts.starters, id: \.self) { s in
                Button { chat.useStarter(s, snapshot: snapshot) } label: {
                    HStack {
                        Text(s).foregroundStyle(t.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up").font(.system(size: 12)).foregroundStyle(t.ink3)
                    }
                }
            }
        } header: { Text("Try asking") } footer: {
            Text(ai.demoMode ? "Demo mode is on, so these get sample replies." : "Hosted providers ask you to confirm what will be sent before the first message.")
        }.rowCard()
    }

    private var conversationSection: some View {
        Section {
            ForEach(chat.messages) { m in
                AIBubble(message: m)
                    .id(m.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if chat.sending {
                HStack(spacing: 8) { ProgressView(); Text("Waiting for \(provider.displayName)…").foregroundStyle(t.ink2) }
                    .listRowBackground(Color.clear)
            }
            if let e = chat.errorText {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Could not get a reply", systemImage: "exclamationmark.triangle").font(.system(size: 14, weight: .semibold)).foregroundStyle(t.ink)
                    Text(e).font(.system(size: 13)).foregroundStyle(t.ink2)
                    HStack(spacing: 16) {
                        if chat.canRetry { Button("Try again") { chat.retry(snapshot: snapshot) } }
                        NavigationLink("AI settings") { AISettingsView() }
                    }.font(.system(size: 14))
                }
                .padding(12)
                .background(t.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .listRowBackground(Color.clear)
            }
            if let r = chat.lastReply, !chat.sending, !ai.demoMode, chat.messages.last?.role == .assistant {
                Text("\(r.provider.displayName) · \(r.model) · \(Int((r.latency * 1000).rounded())) ms")
                    .font(.system(size: 11.5)).foregroundStyle(t.ink3)
                    .listRowBackground(Color.clear)
            }
        }
        .rowCard()
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about a symptom", text: $chat.input, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(t.ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(t.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(t.cardBorder ?? t.ink.opacity(0.12), lineWidth: 1))
            Button {
                inputFocused = false
                chat.send(snapshot: snapshot)
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(t.onPrimary)
                    .frame(width: 40, height: 40)
                    .background(t.ink, in: Circle())
            }
            .disabled(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.sending)
            .opacity(chat.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.sending ? 0.4 : 1)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }
}

/// A plain rounded rectangle with theme colours. The speaker is named in text, not only by colour or side.
struct AIBubble: View {
    @Environment(\.theme) private var t
    let message: AIMessage

    private var mine: Bool { message.role == .user }

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(mine ? "You" : "Alchemy").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(t.ink3)
                    if message.isDemo { Tag(style: .experimental, text: "Demo") }
                    if mine && message.redactedCount > 0 {
                        Text("\(message.redactedCount) item\(message.redactedCount == 1 ? "" : "s") redacted").font(.system(size: 11.5)).foregroundStyle(t.ink3)
                    }
                }
                Text(message.content).font(.system(size: 15)).foregroundStyle(t.ink).textSelection(.enabled)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(mine ? t.soft : t.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(t.cardBorder ?? t.ink.opacity(0.08), lineWidth: 1))
            if !mine { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }
}
