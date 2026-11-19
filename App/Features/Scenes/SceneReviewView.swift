import SwiftUI

@MainActor struct SceneReviewView: View {
    let sceneID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    private let library = SceneLibraryStore.shared
    @State private var editing: SavedScene?
    @State private var confirmDelete = false
    @State private var problem = ""

    var body: some View {
        if let scene = library.state.scene(sceneID) {
            let before = SceneAppearance(model: model)
            let active = library.state.selectedID == scene.id && before == scene.appearance
            List {
                Section("Before · current Assay appearance") { SceneAppearanceLabel(appearance: before) }
                Section {
                    SceneAppearanceLabel(appearance: scene.appearance)
                    if active {
                        Label("Active in Assay", systemImage: "checkmark.circle")
                    } else {
                        Button("Activate scene", systemImage: "checkmark.circle") {
                            do { try library.activate(scene, reviewedFrom: before, on: model); dismiss() }
                            catch { problem = error.localizedDescription }
                        }
                    }
                } header: { Text("After · saved appearance") } footer: {
                    Text("Activation changes only Assay’s theme and stored palette. Undo the latest activation in Scenes.")
                }
                Section {
                    if scene.notes.isEmpty { Text("No placement notes.").foregroundStyle(.secondary) }
                    ForEach(scene.notes, id: \.title) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.subheadline).foregroundStyle(.secondary)
                            Text(note.text)
                        }
                    }
                } header: { Text("Manual placement") } footer: {
                    Text("Nothing here is applied to your wallpaper, icons or widgets.")
                }
                Section("Wallpaper artwork") { SceneWallpaperOutput(palette: scene.appearance.palette) }
                Section {
                    Button("Edit scene", systemImage: "pencil") { editing = scene }
                    ShareLink(item: scene.shareText) { Label("Share scene notes and colours", systemImage: "square.and.arrow.up") }
                    Button("Delete scene", role: .destructive) { confirmDelete = true }
                        .confirmationDialog("Delete \(scene.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete scene", role: .destructive) {
                                do { try library.delete(sceneID); dismiss() } catch { problem = error.localizedDescription }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: { Text("This removes the saved scene and its notes. Your current appearance won’t change.") }
                }
            }
            .navigationTitle(scene.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { SceneEditorView(initial: $0, creating: false) }
            .sceneProblem($problem)
        } else {
            ContentUnavailableView("Scene unavailable", systemImage: "square.2.layers.3d")
        }
    }
}

private extension SavedScene {
    var notes: [(title: String, text: String)] {
        [("Wallpaper", wallpaperNote), ("Icons", iconNote), ("Widgets", widgetNote)]
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var shareText: String {
        (["Assay scene: \(name)", "Theme: \(appearance.theme.title)", "Palette: \(ScenePalettes.codes(appearance.palette))", "Manual placement notes (not applied):"]
            + notes.map { "\($0.title): \($0.text)" }).joined(separator: "\n")
    }
}
