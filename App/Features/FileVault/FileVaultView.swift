import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct FileVaultView: View {
    @State private var history = VaultHistory()
    @State private var picking = false
    @State private var restore: Selection?
    @State private var operation: UUID?
    @State private var status = ""
    @State private var loaded = false
    private struct Selection { let snapshot: UUID, file: UUID }

    var body: some View {
        List {
            Section {
                Button {
                    restore = nil
                    picking = true
                } label: { Label("Choose files for checkpoint", systemImage: "doc.badge.plus") }
                .disabled(operation != nil)
                .rowCard()
            } header: { Text("Selected files only") } footer: {
                Text("Save up to 32 individual files: 16 MiB per file, 64 MiB per checkpoint. Identical contents are stored once. This is not a device or app backup.")
            }
            if !status.isEmpty {
                Section("Status") {
                    HStack {
                        if operation != nil { ProgressView().accessibilityHidden(true) }
                        Text(status)
                    }.rowCard()
                }
            }
            Section {
                if history.unreadable > 0 { Text("Unreadable checkpoints: \(history.unreadable)").rowCard() }
                if loaded && history.snapshots.isEmpty && history.unreadable == 0 { Text("No checkpoints yet.").rowCard() }
                ForEach(history.snapshots) { snapshot in
                    DisclosureGroup {
                        ForEach(snapshot.files) { file in
                            Button {
                                restore = Selection(snapshot: snapshot.id, file: file.id)
                                picking = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: file.name).privacySensitive()
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .accessibilityHint("Choose a folder for a verified copy")
                            .disabled(operation != nil)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(snapshot.date.formatted(date: .abbreviated, time: .standard))
                            Text("Files: \(snapshot.files.count)").font(.caption).foregroundStyle(.secondary)
                        }
                    }.rowCard()
                }
            } header: { Text("Checkpoints") } footer: {
                Text("Open a checkpoint and tap a file to restore it to a folder in Files. An existing file is never replaced. Vault copies stay in Assay until you export them; deleting Assay removes the vault.")
            }
        }
        .themedList()
        .navigationTitle("Files Vault")
        .fileImporter(isPresented: $picking, allowedContentTypes: restore == nil ? [.item] : [.folder],
                      allowsMultipleSelection: restore == nil) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                let selection = restore
                Task { await perform(urls, selection) }
            case .failure(let error):
                let e = error as NSError
                status = e.domain == NSCocoaErrorDomain && e.code == NSUserCancelledError
                    ? "Selection cancelled." : "Files could not open the selection. Try again."
            }
        }
        .task {
            do { history = try await VaultStore.shared.history(); loaded = true }
            catch { status = "Could not load checkpoint history." }
        }
    }

    private func perform(_ urls: [URL], _ selection: Selection?) async {
        guard operation == nil else { return }
        let token = UUID()
        operation = token
        defer { operation = nil }
        status = "Opening selection…"
        let progress: @Sendable (String) -> Void = { message in
            DispatchQueue.main.async { if operation == token { status = message } }
        }
        do {
            if let selection {
                try await VaultStore.shared.restore(snapshot: selection.snapshot, file: selection.file, to: urls[0], progress: progress)
                status = "Verified copy saved to the selected folder."
            } else {
                let s = try await VaultStore.shared.checkpoint(urls, progress: progress)
                history.snapshots.insert(s, at: 0)
                status = "Checkpoint saved and verified. Files: \(s.files.count)."
            }
        } catch let fault as VaultFault { status = fault.rawValue }
        catch is CancellationError { status = "Operation cancelled." }
        catch { status = "Could not complete the operation. Check file availability, free space and access." }
    }
}
