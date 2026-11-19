import SwiftUI
import UniformTypeIdentifiers

/// Destination in the parent's existing NavigationStack. No live AppModel is needed.
@MainActor struct SceneTransferView: View {
    private let library = SceneLibraryStore.shared
    @State private var selected: UUID?
    @State private var includeNotes = false
    @State private var picking = false
    @State private var reading = false
    @State private var review: TransferReview?
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                if !library.readable { Text(SceneLibraryError.unavailable.localizedDescription) }
                else if library.state.scenes.isEmpty { Text("No saved scenes to export. You can still import one below.") }
                else {
                    Picker("Scene", selection: $selected) {
                        Text("Choose a scene").tag(nil as UUID?)
                        ForEach(library.state.scenes) { scene in Text(verbatim: scene.name).tag(Optional(scene.id)) }
                    }
                    if let scene = library.state.scene(selected) {
                        Toggle("Include manual note content", isOn: $includeNotes)
                        Button("Review export") {
                            do {
                                review = try TransferReview(ScenePacket(scene: scene, includeNotes: includeNotes), importing: false)
                                includeNotes = false
                            } catch { message = error.localizedDescription }
                        }
                    }
                }
            } header: { Text("Export one scene") } footer: {
                Text("Name, theme and palette are shared. Notes are off by default; check them for private information before sharing.")
            }
            Section {
                Button("Choose scene JSON from Files") { message = ""; picking = true }
                    .disabled(reading || !library.readable)
                if reading { ProgressView("Reading scene…") }
            } header: { Text("Import a copy") } footer: {
                Text("Review the fields before saving a new scene. Import never changes your appearance or replaces a saved scene.")
            }
            if !message.isEmpty { Section("Status") { Text(verbatim: message) } }
        }
        .disabled(reading)
        .navigationTitle("Share scenes")
        .onChange(of: selected) { _, _ in includeNotes = false; message = "" }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            switch result {
            case .failure(let error):
                if !Self.cancelled(error) { message = "Could not open that file." }
            case .success(let url):
                reading = true
                Task {
                    defer { reading = false }
                    do {
                        let packet = try await Task.detached(priority: .userInitiated) { try SceneJSONFile.read(url) }.value
                        review = try TransferReview(packet, importing: true)
                    } catch { message = (error as? ScenePacket.Fault)?.localizedDescription ?? "Could not read that file." }
                }
            }
        }
        .sheet(item: $review) { item in
            TransferReviewSheet(item: item) { result in message = result; review = nil }
        }
    }

    fileprivate static func cancelled(_ error: Error) -> Bool {
        (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError
    }
}

private struct TransferReview: Identifiable {
    let id = UUID()
    let packet: ScenePacket
    let data: Data
    let importing: Bool
    init(_ packet: ScenePacket, importing: Bool) throws {
        self.data = try packet.encoded()
        self.packet = packet
        self.importing = importing
    }
}

@MainActor private struct TransferReviewSheet: View {
    let item: TransferReview
    let finish: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var committed = false
    @State private var problem = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Verbatim, not Markdown or attributed text. No URL or action dispatch.
                    Text(verbatim: String(decoding: item.data, as: UTF8.self))
                        .font(.body.monospaced()).fixedSize(horizontal: false, vertical: true)
                } header: { Text("All document fields") } footer: {
                    Text(item.importing ? "These are the only fields that will be copied. Notes are reminders, not actions." : "These are the exact contents of the JSON file. Cancel if anything here should stay private.")
                }
                if item.importing {
                    Button("Save as new scene") {
                        guard !committed else { return }
                        do {
                            try SceneLibraryStore.shared.save(item.packet.newLocalScene(), creating: true)
                            committed = true
                            finish("Saved a new scene. Your current appearance is unchanged.")
                        } catch { problem = error.localizedDescription }
                    }.disabled(committed)
                } else {
                    Button("Export JSON to Files") { exporting = true }
                }
                if !problem.isEmpty { Text(verbatim: problem) }
            }
            .navigationTitle(item.importing ? "Review import" : "Review export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: SceneJSONFile(data: item.data), contentType: .json,
                          defaultFilename: "Assay-scene-v1.json") { result in
                switch result {
                case .success: finish("Scene JSON exported.")
                case .failure(let error):
                    if !SceneTransferView.cancelled(error) { problem = "Could not export the file. Try another folder." }
                }
            }
        }
    }
}
