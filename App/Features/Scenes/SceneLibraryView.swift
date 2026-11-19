import SwiftUI

/// Destination inside the existing Scenes tab's NavigationStack.
@MainActor struct SceneLibraryView: View {
    @Environment(AppModel.self) private var model
    private let library = SceneLibraryStore.shared
    @State private var draft: SavedScene?
    @State private var problem = ""

    var body: some View {
        let live = SceneAppearance(model: model)
        List {
            Section("In use in Assay") {
                VStack(alignment: .leading, spacing: 5) {
                    Text(library.state.scene(library.state.selectedID)?.name ?? "Current appearance").font(.headline)
                    SceneAppearanceLabel(appearance: live)
                }
                if let undo = library.state.undo, undo.after == live {
                    Button("Undo activation", systemImage: "arrow.uturn.backward") {
                        do { try library.undo(undo.id, on: model) } catch { problem = error.localizedDescription }
                    }
                    .accessibilityHint("Restores the previous theme and palette.")
                }
            }
            Section {
                if !library.readable {
                    Text(SceneLibraryError.unavailable.localizedDescription)
                } else if library.state.scenes.isEmpty {
                    ContentUnavailableView("No scenes yet", systemImage: "square.2.layers.3d", description: Text("Save an Assay appearance to return to later."))
                } else {
                    ForEach(library.state.scenes) { scene in
                        NavigationLink {
                            SceneReviewView(sceneID: scene.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scene.name)
                                Text(scene.id == library.state.selectedID ? "Active · \(scene.appearance.theme.title)" : scene.appearance.theme.title)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if library.readable {
                    Button("New scene", systemImage: "plus") { draft = SavedScene(appearance: live) }
                }
            } header: { Text("My scenes") } footer: {
                Text("Scenes switch Assay’s appearance. Home Screen wallpaper, icons and widgets are yours to arrange.")
            }
        }
        .navigationTitle("Scenes")
        .onAppear { library.attach(to: model) }
        .sheet(item: $draft) { SceneEditorView(initial: $0, creating: true) }
        .sceneProblem($problem)
    }
}

extension View {
    func sceneProblem(_ message: Binding<String>) -> some View {
        alert("Scene not updated", isPresented: Binding(get: { !message.wrappedValue.isEmpty }, set: { if !$0 { message.wrappedValue = "" } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(message.wrappedValue) }
    }
}
