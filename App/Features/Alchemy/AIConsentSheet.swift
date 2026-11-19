import SwiftUI

/// What the first-message sheet is asking permission for. Built from the already-redacted outgoing text.
struct AIPendingSend: Identifiable {
    let id = UUID()
    var provider: AIProviderKind
    var model: String
    var baseURL: String
    var outgoing: AIOutgoing
    var withContext: Bool
}

/// Shown before the first message to a hosted provider (and again if device context is added later).
/// Lists exactly what will be sent. Nothing leaves the phone until the toggle is on and Send is tapped.
struct AIConsentSheet: View {
    @Environment(\.theme) private var t
    let pending: AIPendingSend
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @State private var agreed = false

    private var providerName: String { pending.provider.displayName }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: AIPrivacyLabel.leavesPhone.symbol).foregroundStyle(t.ink)
                        Text(AIPrivacyLabel.leavesPhone.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.ink)
                        Spacer()
                        Tag(style: .caution, text: providerName)
                    }
                    Text("Exactly the text below is sent to \(providerName), plus your API key as a header so they can bill you. Assay does not send anything else: no UDID, serial number, ECID or pairing data.")
                        .font(.system(size: 13)).foregroundStyle(t.ink2)
                    LabeledContent("Model") { Text(pending.model).foregroundStyle(t.ink2) }
                }.rowCard()

                Section {
                    Text(pending.outgoing.system).font(.system(size: 13)).foregroundStyle(t.ink2).textSelection(.enabled)
                } header: { Text("System prompt") }.rowCard()

                Section {
                    ForEach(pending.outgoing.messages) { m in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.role == .user ? "You" : "Earlier reply").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink3)
                            Text(m.content).font(.system(size: 14)).foregroundStyle(t.ink).textSelection(.enabled)
                        }
                    }
                } header: { Text(pending.outgoing.messages.count == 1 ? "Your message" : "Conversation so far") }.rowCard()

                Section {
                    if pending.outgoing.redactedCount > 0 {
                        LabeledContent("Redacted") {
                            Text("\(pending.outgoing.redactedCount) item\(pending.outgoing.redactedCount == 1 ? "" : "s") redacted").foregroundStyle(t.ink)
                        }
                        Text("Removed before sending: " + pending.outgoing.categories.joined(separator: ", ") + ". Replaced with a bracketed placeholder in the text above.")
                            .font(.system(size: 12.5)).foregroundStyle(t.ink3)
                    } else {
                        LabeledContent("Redacted") { Text("0 items redacted").foregroundStyle(t.ink2) }
                        Text("Assay looks for UDID-, serial-, ECID- and key-like strings. It can miss things, so read the text above.")
                            .font(.system(size: 12.5)).foregroundStyle(t.ink3)
                    }
                    if pending.withContext {
                        Text("Device context is included: model and iOS version only.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
                    }
                }.rowCard()

                Section {
                    Toggle("Send to \(providerName)", isOn: $agreed)
                    Text("Asked once per provider. You can withdraw it in AI settings.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
                }.rowCard()
            }
            .themedList()
            .navigationTitle("Before this is sent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onCancel() } } }
            .safeAreaInset(edge: .bottom) {
                Button { onConfirm() } label: { Text("Send to \(providerName)") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!agreed)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .interactiveDismissDisabled()
    }
}
