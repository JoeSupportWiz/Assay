import Foundation

struct SceneAppearance: Codable, Equatable {
    var theme: ThemeID
    var palette: WallpaperPalette
}

struct SavedScene: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var appearance: SceneAppearance
    var wallpaperNote = ""
    var iconNote = ""
    var widgetNote = ""
}

struct SceneUndo: Identifiable, Codable, Equatable {
    let id: UUID
    let before: SceneAppearance
    let after: SceneAppearance
    let previousSceneID: UUID?
}

enum SceneLibraryError: LocalizedError {
    case missing, invalidName, noteTooLong, stale, unavailable
    var errorDescription: String? {
        switch self {
        case .missing: "This scene is no longer in the library."
        case .invalidName: "Use a scene name between 1 and 80 characters."
        case .noteTooLong: "Keep each placement note under 2,001 characters."
        case .stale: "The scene or appearance changed. Review the current settings before trying again."
        case .unavailable: "The scene library could not be read. Your saved file has not been replaced."
        }
    }
}

/// Value-type transitions: no defaults access, view state or writes to AppModel.
struct SceneLibraryState: Codable, Equatable {
    private(set) var scenes: [SavedScene] = []
    private(set) var selectedID: UUID?
    private(set) var undo: SceneUndo?

    func scene(_ id: UUID?) -> SavedScene? { scenes.first { $0.id == id } }

    mutating func save(_ draft: SavedScene, creating: Bool) throws {
        var saved = draft
        saved.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(saved.name.count) else { throw SceneLibraryError.invalidName }
        guard [saved.wallpaperNote, saved.iconNote, saved.widgetNote].allSatisfy({ $0.count <= 2000 }) else {
            throw SceneLibraryError.noteTooLong
        }
        if creating {
            guard scene(saved.id) == nil else { throw SceneLibraryError.stale }
            scenes.append(saved)
        } else {
            guard let index = scenes.firstIndex(where: { $0.id == saved.id }) else { throw SceneLibraryError.missing }
            if selectedID == saved.id, scenes[index].appearance != saved.appearance { selectedID = nil }
            scenes[index] = saved
        }
    }

    mutating func delete(_ id: UUID) {
        scenes.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
    }

    mutating func forgetSelection() { selectedID = nil; undo = nil }

    mutating func reconcile(with live: SceneAppearance) {
        if let undo, undo.after != live { forgetSelection() }
        if selectedID != nil, scene(selectedID)?.appearance != live { selectedID = nil }
    }

    mutating func activate(_ reviewed: SavedScene, before: SceneAppearance, live: SceneAppearance) throws -> SceneAppearance {
        guard scene(reviewed.id) == reviewed, before == live else { throw SceneLibraryError.stale }
        reconcile(with: live)
        undo = SceneUndo(id: UUID(), before: live, after: reviewed.appearance, previousSceneID: selectedID)
        selectedID = reviewed.id
        return reviewed.appearance
    }

    mutating func restore(token: UUID, live: SceneAppearance) throws -> SceneAppearance {
        reconcile(with: live)
        guard let undo, token == undo.id else { throw SceneLibraryError.stale }
        selectedID = scene(undo.previousSceneID)?.appearance == undo.before ? undo.previousSceneID : nil
        self.undo = nil
        return undo.before
    }
}
