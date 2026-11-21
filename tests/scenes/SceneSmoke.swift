import Foundation
import Observation

// Synthetic stand-ins for the SwiftUI target's appearance types. Never linked into App.
enum ThemeID: String, Codable { case auto, light, dark, wallpaper }
struct WallpaperPalette: Equatable, Codable { var hex: [UInt32] }
@Observable final class AppModel {
    var themeID = ThemeID.auto
    var wallpaperPalette = WallpaperPalette(hex: [1, 7, 7, 14, 2])
}

@main struct SceneSmoke {
    @MainActor static func main() throws {
        let suite = "scene-smoke-\(UUID())"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        var library = SceneLibraryStore(defaults: d)
        let m = AppModel(), start = SceneAppearance(model: m)
        var a = SavedScene(name: " A ", appearance: SceneAppearance(theme: .wallpaper, palette: WallpaperPalette(hex: [8, 6, 4, 3, 1])), iconNote: "Place by hand")
        try library.save(a, creating: true)
        a.name = "A"
        precondition(library.state.scenes == [a] && SceneAppearance(model: m) == start)
        try library.activate(a, reviewedFrom: start, on: m)
        let old = library.state.undo!.id
        let b = SavedScene(name: "B", appearance: a.appearance)
        try library.save(b, creating: true)
        try library.activate(b, reviewedFrom: a.appearance, on: m)
        do { try library.undo(old, on: m); fatalError("stale activation token") } catch SceneLibraryError.stale { }
        try library.undo(library.state.undo!.id, on: m)
        precondition(library.state.selectedID == a.id && library.state.undo == nil)

        m.themeID = start.theme
        m.wallpaperPalette = start.palette
        try library.activate(a, reviewedFrom: start, on: m)
        precondition(SceneAppearance(model: m) == a.appearance)
        // Reconstruct using the same saved domain, before the first store can observe further changes.
        library = SceneLibraryStore(defaults: d)
        library.attach(to: m)
        precondition(library.state.selectedID == a.id && library.state.scenes.count == 2)
        try library.delete(a.id)
        try library.undo(library.state.undo!.id, on: m)
        precondition(SceneAppearance(model: m) == start && library.state.selectedID == nil)
        var edited = b
        edited.name = "Renamed"
        edited.widgetNote = "Top row"
        try library.save(edited, creating: false)
        do { try library.activate(b, reviewedFrom: start, on: m); fatalError("stale reviewed scene") } catch SceneLibraryError.stale { }
        try library.activate(edited, reviewedFrom: start, on: m)
        let token = library.state.undo!.id
        m.wallpaperPalette = start.palette
        m.wallpaperPalette = edited.appearance.palette
        do { try library.undo(token, on: m); fatalError("outside palette write") } catch SceneLibraryError.stale { }
        precondition(SceneAppearance(model: m) == edited.appearance && library.state.selectedID == nil)
        precondition(SceneLibraryStore(defaults: d).state.undo == nil)
        let bad = Data([0xFF])
        d.set(bad, forKey: SceneLibraryStore.key)
        let broken = SceneLibraryStore(defaults: d)
        do { try broken.save(a, creating: true); fatalError("unreadable library replaced") } catch SceneLibraryError.unavailable { }
        precondition(d.data(forKey: SceneLibraryStore.key) == bad)
        print("PASS: scene CRUD, review, both appearance setters, relaunch, undo and invalidation")
    }
}
