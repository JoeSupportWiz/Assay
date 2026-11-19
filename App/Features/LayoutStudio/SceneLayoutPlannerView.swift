import SwiftUI

/// Destination for the host's NavigationStack. Reading a scene never activates it.
@MainActor struct SceneLayoutPlannerView: View {
    private let library = SceneLibraryStore.shared
    @State private var draft = LayoutRecipe()
    @State private var awaitingStarter: LayoutStarter?
    @State private var confirmStarter = false
    @State private var history: [LayoutSnapshot] = []
    @State private var storageIssue: String?
    @State private var lastSave: LayoutSnapshot?

    var body: some View {
        Form {
            Section {
                Menu("Start from a recipe") { ForEach(LayoutStarter.allCases) { starter in
                    Button(starter.rawValue) { if draft == LayoutRecipe() { draft = starter.recipe } else { awaitingStarter=starter; confirmStarter=true } }
                }}
                TextField("Page label", text: $draft.page)
                TextField("Purpose (optional)", text: $draft.purpose)
                TextField("App labels, one per line", text: $draft.appLines, axis: .vertical)
                    .lineLimit(3...8).autocorrectionDisabled()
            } header: { Text("Your page") } footer: {
                Text("Enter the labels in the order you want them. This is a sketch, not a copy of your Home Screen.")
            }
            Section {
                Picker("Keep clear", selection: $draft.focus) {
                    ForEach(LayoutRecipe.Focus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Widget space", selection: $draft.widget) {
                    Text("None").tag(LayoutRecipe.Widget.none)
                    Text("Small · 2 × 2").tag(LayoutRecipe.Widget.small)
                    Text("Medium · 4 × 2").tag(LayoutRecipe.Widget.medium)
                }
            } header: { Text("Leave room") } footer: {
                Text("Keep two rows clear for the wallpaper subject. Widget space starts in the first available pair of rows.")
            }
            LayoutPreviewSections(recipe: draft)
            Section {
                Picker("Link to scene", selection: $draft.sceneID) {
                    Text("No scene").tag(nil as UUID?)
                    if let id = draft.sceneID, sceneMissing { Text("Unavailable scene").tag(Optional(id)) }
                    ForEach(library.state.scenes) { scene in Text(scene.name).tag(Optional(scene.id)) }
                }
                Button("Save layout", systemImage: "plus.rectangle.on.folder", action: save)
                    .disabled(draft.title.isEmpty || sceneMissing)
                if lastSave?.recipe == draft { Label("Layout saved", systemImage: "checkmark") }
            } header: { Text("Keep a copy") } footer: {
                if sceneMissing { Text("The linked scene is unavailable. Choose another scene or No scene to save a new copy.") }
                else if !library.readable { Text("The scene library is unavailable. You can still save a named layout without a scene.") }
                else { Text("Each save keeps a new local copy without changing the scene or Home Screen.") }
            }
            Section("Saved layouts") {
                if let storageIssue {
                    Label(storageIssue, systemImage: "exclamationmark.triangle")
                    Button("Reload saved layouts", action: reload)
                } else if history.isEmpty { Text("No saved layouts yet.").foregroundStyle(.secondary) }
                ForEach(history) { snapshot in
                    NavigationLink {
                        LayoutSnapshotReview(snapshot: snapshot) { draft = snapshot.recipe; lastSave = nil }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(snapshot.recipe.title)
                            Text(snapshot.savedAt, format: .dateTime.day().month().year().hour().minute().second())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Layout planner")
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Replace this unsaved draft?",isPresented:$confirmStarter,titleVisibility:.visible) { Button("Use recipe") { if let st=awaitingStarter { draft=st.recipe;lastSave=nil };awaitingStarter=nil };Button("Cancel",role:.cancel){awaitingStarter=nil} } message:{Text("Saved layouts stay unchanged.")}
        .onAppear { reload(); if ProcessInfo.processInfo.arguments.contains("-layoutSample") && draft == LayoutRecipe() { draft=LayoutStarter.work.recipe } }
    }

    private var sceneMissing: Bool { draft.sceneID != nil && library.state.scene(draft.sceneID) == nil }

    private func reload() {
        do { history = try LayoutArchive.local().load(); storageIssue = nil }
        catch { storageIssue = "Saved layouts could not be read. \(error.localizedDescription)" }
    }

    private func save() {
        guard !draft.title.isEmpty, !sceneMissing else { return }
        let snapshot = LayoutSnapshot(recipe: draft, sceneNameAtSave: library.state.scene(draft.sceneID)?.name)
        do {
            history = try LayoutArchive.local().save(snapshot)
            lastSave = snapshot
            storageIssue = nil
        } catch {
            lastSave = nil
            storageIssue = "Layout not saved. \(error.localizedDescription)"
        }
    }
}

@MainActor private struct LayoutSnapshotReview: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: LayoutSnapshot
    let restore: () -> Void
    @State private var confirming = false

    var body: some View {
        List {
            Section("Saved page") {
                if !snapshot.recipe.purpose.isEmpty { LabeledContent("Purpose", value: snapshot.recipe.purpose) }
                LabeledContent("Clear area", value: snapshot.recipe.focus.rawValue.capitalized)
                LabeledContent("Widget space", value: snapshot.recipe.widget.rawValue.capitalized)
                LabeledContent("Scene", value: sceneLabel)
            }
            LayoutPreviewSections(recipe: snapshot.recipe)
            NavigationLink { PlacementWalkthrough(snapshot:snapshot) } label: { Label("Placement checklist",systemImage:"checklist") }
            Button("Restore as draft", systemImage: "arrow.uturn.backward") { confirming = true }
                .confirmationDialog("Replace the current draft?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Replace draft") { restore(); dismiss() }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Saved copies stay unchanged.") }
        }
        .navigationTitle(snapshot.recipe.title)
    }

    private var sceneLabel: String {
        guard let id = snapshot.recipe.sceneID else { return "No scene" }
        return SceneLibraryStore.shared.state.scene(id)?.name ?? "\(snapshot.sceneNameAtSave ?? "Scene") (unavailable)"
    }
}
