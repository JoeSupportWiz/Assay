import SwiftUI

enum ScenePalettes {
    static let options: [(name: String, value: WallpaperPalette)] = [
        ("Dusk", .dusk),
        ("Tide", WallpaperPalette(hex: [0xDCFAF5, 0x94DCD3, 0x59ADAE, 0x256777, 0x103448])),
        ("Plum", WallpaperPalette(hex: [0xFFE4EF, 0xEFB9D3, 0xC181AB, 0x794879, 0x38213E]))
    ]
    static func name(for palette: WallpaperPalette) -> String {
        options.first { $0.value == palette }?.name ?? "Custom"
    }
    static func codes(_ palette: WallpaperPalette) -> String {
        palette.hex.map { String(format: "#%06X", $0) }.joined(separator: " ")
    }
}

struct SceneAppearanceLabel: View {
    let appearance: SceneAppearance
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(appearance.theme.title) · \(ScenePalettes.name(for: appearance.palette)) palette")
            HStack(spacing: 4) {
                ForEach(appearance.palette.hex.indices, id: \.self) { i in
                    Circle().fill(Color(hex: appearance.palette.hex[i])).frame(width: 16, height: 16)
                        .overlay { Circle().stroke(.secondary.opacity(0.5), lineWidth: 0.5) }
                }
            }.accessibilityHidden(true)
            if ScenePalettes.name(for: appearance.palette) == "Custom" {
                Text(ScenePalettes.codes(appearance.palette)).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor struct SceneEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let initial: SavedScene
    let creating: Bool
    @State private var draft: SavedScene
    @State private var problem = ""

    init(initial: SavedScene, creating: Bool) {
        self.initial = initial
        self.creating = creating
        _draft = State(initialValue: initial)
    }

    private var palettes: [(name: String, value: WallpaperPalette)] {
        var options = ScenePalettes.options
        if !options.contains(where: { $0.value == model.wallpaperPalette }) {
            options.append(("Current Assay palette", model.wallpaperPalette))
        }
        if !options.contains(where: { $0.value == initial.appearance.palette }) {
            options.append(("Saved palette", initial.appearance.palette))
        }
        if !options.contains(where: { $0.value == draft.appearance.palette }) { options.append(("Draft palette",draft.appearance.palette)) }
        return options
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Scene name", text: $draft.name) }
                Section {
                    Picker("Theme", selection: $draft.appearance.theme) {
                        ForEach(ThemeID.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Palette", selection: $draft.appearance.palette.hex) {
                        ForEach(palettes, id: \.value.hex) { item in Text(item.name).tag(item.value.hex) }
                    }
                    NavigationLink("Choose colours from a photo") { ScenePaletteLabView { draft.appearance.palette = $0 } }
                    SceneAppearanceLabel(appearance: draft.appearance)
                } header: { Text("Assay appearance") } footer: {
                    Text("Wallpaper match displays these colours inside Assay. Other themes keep the palette for later.")
                }
                Section {
                    TextField("Wallpaper idea", text: $draft.wallpaperNote, axis: .vertical)
                    TextField("Icon placement", text: $draft.iconNote, axis: .vertical)
                    TextField("Widget placement", text: $draft.widgetNote, axis: .vertical)
                } header: { Text("Manual notes · optional") } footer: {
                    Text("These are reminders, not system changes. Saving a scene does not activate it.")
                }
            }
            .navigationTitle(creating ? "New scene" : "Edit scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try SceneLibraryStore.shared.save(draft, creating: creating); dismiss() }
                        catch { problem = error.localizedDescription }
                    }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sceneProblem($problem)
        }
    }
}
