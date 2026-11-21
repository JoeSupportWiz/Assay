import Foundation
import Observation

extension SceneAppearance {
    init(model: AppModel) { self.init(theme: model.themeID, palette: model.wallpaperPalette) }

    func apply(to model: AppModel) {
        model.wallpaperPalette = palette
        model.themeID = theme
    }
}

/// Observation fires on willSet. Latch synchronously, even if an outside writer
/// changes away and back before the main actor gets another turn.
private final class AppearanceWatch: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func mark() { lock.withLock { fired = true } }
    var changed: Bool { lock.withLock { fired } }
}

@MainActor @Observable
final class SceneLibraryStore {
    static let shared = SceneLibraryStore()
    static let key = "assay.scene-library.v1"
    private(set) var state = SceneLibraryState()
    private(set) var readable = true
    private let defaults: UserDefaults
    @ObservationIgnored private weak var observed: AppModel?
    @ObservationIgnored private var watch: AppearanceWatch?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.key) != nil {
            if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(SceneLibraryState.self, from: data) {
                state = saved
            } else { readable = false }
        }
    }

    private func commit(_ next: SceneLibraryState) throws {
        guard readable else { throw SceneLibraryError.unavailable }
        guard state != next else { return }
        defaults.set(try JSONEncoder().encode(next), forKey: Self.key)
        state = next
    }

    /// Can be attached at app startup as well as at entry to the library.
    func attach(to model: AppModel) {
        if observed !== model { watch = nil; observed = model }
        var next = state
        if watch?.changed == true { next.forgetSelection(); watch = nil }
        next.reconcile(with: SceneAppearance(model: model))
        do { try commit(next) } catch { readable = false; return }
        guard watch == nil, next.undo != nil || next.selectedID != nil else { return }
        let ticket = AppearanceWatch()
        watch = ticket
        withObservationTracking {
            _ = model.themeID
            _ = model.wallpaperPalette
        } onChange: { [weak self, weak model] in
            ticket.mark()
            Task { @MainActor in
                guard let self, let model, self.watch === ticket else { return }
                self.attach(to: model)
            }
        }
    }

    func save(_ draft: SavedScene, creating: Bool) throws {
        var next = state
        try next.save(draft, creating: creating)
        try commit(next)
    }

    func delete(_ id: UUID) throws {
        var next = state
        next.delete(id)
        try commit(next)
    }

    func activate(_ scene: SavedScene, reviewedFrom: SceneAppearance, on model: AppModel) throws {
        attach(to: model)
        var next = state
        let target = try next.activate(scene, before: reviewedFrom, live: SceneAppearance(model: model))
        try commit(next)
        watch = nil // Retire the old ticket before our own pair of setters fires it.
        target.apply(to: model)
        attach(to: model)
    }

    func undo(_ token: UUID, on model: AppModel) throws {
        attach(to: model)
        var next = state
        let target = try next.restore(token: token, live: SceneAppearance(model: model))
        try commit(next)
        watch = nil
        target.apply(to: model)
        attach(to: model)
    }
}
