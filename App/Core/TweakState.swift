import Foundation
import Observation

/// Tweaks currently on, read from the device, and the user's staged edits. Toggling never applies anything.
@Observable
final class TweakState {
    /// Current device values (nil = key not set, or unreadable). Only meaningful when `loaded`.
    private(set) var current: [String: PlistValue] = [:]
    private(set) var loaded = false
    /// What the user wants, keyed by tweak id. `nil` entry value means "turn off".
    var staged: [String: PlistValue?] = [:]
    var search = ""
    var category: Tweak.Category?

    func load(engine: any DeviceEngine) async {
        guard engine.canRead else { loaded = false; current = [:]; return }
        var map: [String: PlistValue] = [:]
        for t in TweakCatalog.all { if let v = await engine.read(t.target) { map[t.id] = v } }
        current = map; loaded = true
    }

    func isOn(_ t: Tweak) -> Bool { current[t.id] != nil }

    /// Effective on/off including staged edits.
    func effectiveOn(_ t: Tweak) -> Bool {
        if let s = staged[t.id] { return s != nil }
        return isOn(t)
    }

    func effectiveValue(_ t: Tweak) -> PlistValue? {
        if let s = staged[t.id] { return s }
        return current[t.id]
    }

    func stage(_ t: Tweak, value: PlistValue?) {
        // Drop the edit if it matches what's already on the device.
        if loaded && value == current[t.id] { staged.removeValue(forKey: t.id) } else { staged[t.id] = .some(value) }
    }

    func toggle(_ t: Tweak, on: Bool) { stage(t, value: on ? t.onValue : nil) }

    func discard() { staged = [:] }
    var stagedCount: Int { staged.count }

    /// Highest tier among staged edits.
    var stagedTier: Tier {
        staged.keys.compactMap { TweakCatalog.tweak($0)?.tier }.max() ?? .reversible
    }

    func plan(title: String? = nil) -> OperationPlan? {
        let items = staged.compactMap { (id, value) -> Change? in
            guard let t = TweakCatalog.tweak(id) else { return nil }
            let after: PlistValue? = value
            return Change(label: after == nil ? "Turn off: \(t.title)" : "Turn on: \(t.title)", target: t.target,
                          before: current[id], after: after, tier: t.tier, beforeKnown: loaded)
        }.sorted { $0.label < $1.label }
        guard !items.isEmpty else { return nil }
        let respring = staged.keys.contains { TweakCatalog.tweak($0)?.respring == true }
        return OperationPlan(title: title ?? (items.count == 1 ? items[0].label : "\(items.count) tweaks"), kind: .tweak, changes: items,
                             needsRespring: respring, userCheck: "Does everything look right?")
    }

    func apply(preset: Preset) {
        for t in preset.tweaks { stage(t, value: t.onValue) }
    }

    func filtered(osVersion: String) -> [Tweak] {
        TweakCatalog.all.filter { t in
            (category == nil || t.category == category) &&
            (search.isEmpty || (t.title + " " + t.detail + " " + t.target.key).localizedCaseInsensitiveContains(search))
        }
    }
}
