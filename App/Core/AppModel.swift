import SwiftUI
import Observation

/// How Assay reaches the device. Chosen at onboarding, switchable in More › Engine.
enum EngineMode: String, Codable, CaseIterable, Identifiable {
    case mac, iphone, demo
    var id: String { rawValue }
    var title: String { switch self { case .mac: "Mac companion"; case .iphone: "iPhone only"; case .demo: "Demo" } }
    var symbol: String { switch self { case .mac: "laptopcomputer"; case .iphone: "iphone"; case .demo: "sparkles.rectangle.stack" } }
}

/// One place for app-wide state. Persisted settings live in UserDefaults; secrets never do (see Vault/Keychain).
@Observable
final class AppModel {
    // Persisted settings
    var themeID: ThemeID { didSet { save() } }
    var wallpaperPalette: WallpaperPalette { didSet { save() } }
    var engineMode: EngineMode? { didSet { save(); rebuildEngine() } }
    var hasOnboarded: Bool { didSet { save() } }
    var expertMode: Bool { didSet { save() } }
    var userName: String { didSet { save() } }

    // Live state
    var selectedTab: AppTab = .home
    var showSearch = false
    var toast: Toast?
    private(set) var engine: any DeviceEngine = DemoEngine()
    var snapshot: DeviceSnapshot?

    init() {
        let d = UserDefaults.standard
        themeID = ThemeID(rawValue: d.string(forKey: "themeID") ?? "") ?? .auto
        wallpaperPalette = (d.data(forKey: "wallpaperPalette")).flatMap { try? JSONDecoder().decode(WallpaperPalette.self, from: $0) } ?? .dusk
        engineMode = EngineMode(rawValue: d.string(forKey: "engineMode") ?? "")
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        expertMode = d.bool(forKey: "expertMode")
        userName = d.string(forKey: "userName") ?? ""
        // Screenshot / UI-test hooks (CI renders every screen with deterministic state).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiDemo") { hasOnboarded = true; engineMode = .demo; userName = "Joe" }
        if let i = args.firstIndex(of: "-theme"), i + 1 < args.count, let id = ThemeID(rawValue: args[i + 1]) { themeID = id }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = AppTab(rawValue: args[i + 1]) { selectedTab = tab }
        if args.contains("-onboarding") { hasOnboarded = false }
        rebuildEngine()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(themeID.rawValue, forKey: "themeID")
        d.set(try? JSONEncoder().encode(wallpaperPalette), forKey: "wallpaperPalette")
        d.set(engineMode?.rawValue, forKey: "engineMode")
        d.set(hasOnboarded, forKey: "hasOnboarded")
        d.set(expertMode, forKey: "expertMode")
        d.set(userName, forKey: "userName")
    }

    private func rebuildEngine() {
        switch engineMode {
        case .iphone: engine = OnDeviceEngine()
        case .mac: engine = MacCompanionEngine()
        case .demo, .none: engine = DemoEngine()
        }
    }

    func theme(for scheme: ColorScheme) -> Theme {
        switch themeID {
        case .auto: scheme == .dark ? .dark : .light
        case .light: .light
        case .dark: .dark
        case .millennium: .millennium
        case .pinstripe: .pinstripe
        case .wallpaper: .wallpaper(wallpaperPalette)
        }
    }

    @MainActor func refresh() async {
        snapshot = await engine.snapshot()
    }

    @MainActor func show(_ toast: Toast) {
        withAnimation(Motion.bouncy) { self.toast = toast }
        if toast.kind == .success { Haptics.success() } else if toast.kind == .warning { Haptics.warning() }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home, scenes, studio, lab, more
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var activeSymbol: String {
        switch self {
        case .home: "house.fill"; case .scenes: "square.2.layers.3d.fill"; case .studio: "wand.and.stars.inverse"
        case .lab: "flask.fill"; case .more: "ellipsis"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"; case .scenes: "square.2.layers.3d"; case .studio: "wand.and.stars"
        case .lab: "flask"; case .more: "ellipsis"
        }
    }
}

struct Toast: Identifiable, Equatable {
    enum Kind { case success, info, warning }
    let id = UUID()
    var kind: Kind = .info
    var title: String
    var subtitle: String? = nil
    var symbol: String = "checkmark"
}
