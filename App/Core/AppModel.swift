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
    var labPath: [LabRoute] = []
    var toast: Toast?
    private(set) var engine: any DeviceEngine = DemoEngine()
    var snapshot: DeviceSnapshot?
    var findings: [Finding] = []
    var lastCheck: Date?
    var checking = false
    /// Operation being reviewed in the fix sheet.
    var activePlan: OperationPlan?
    var receipts: ReceiptStore
    private let uiDemo: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        uiDemo = args.contains("-uiDemo")
        receipts = uiDemo ? ReceiptStore(persist: false, seed: ReceiptStore.demoSeed()) : ReceiptStore()
        let d = UserDefaults.standard
        themeID = ThemeID(rawValue: d.string(forKey: "themeID") ?? "") ?? .auto
        wallpaperPalette = (d.data(forKey: "wallpaperPalette")).flatMap { try? JSONDecoder().decode(WallpaperPalette.self, from: $0) } ?? .dusk
        engineMode = EngineMode(rawValue: d.string(forKey: "engineMode") ?? "")
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        expertMode = d.bool(forKey: "expertMode")
        userName = d.string(forKey: "userName") ?? ""
        // Screenshot / UI-test hooks (CI renders every screen with deterministic state).
        if uiDemo { hasOnboarded = true; engineMode = .demo; userName = "Joe" }
        if let i = args.firstIndex(of: "-theme"), i + 1 < args.count, let id = ThemeID(rawValue: args[i + 1]) { themeID = id }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = AppTab(rawValue: args[i + 1]) { selectedTab = tab }
        if args.contains("-onboarding") { hasOnboarded = false }
        rebuildEngine()
        if let i = args.firstIndex(of: "-route"), i + 1 < args.count {
            let r = args[i + 1]
            selectedTab = .lab
            if r == "diagnose" { labPath = [.diagnose] }
            else if r == "history" { labPath = [.history] }
            else if r.hasPrefix("symptom:") { labPath = [.diagnose, .symptom(String(r.dropFirst(8)))] }
            else if r.hasPrefix("fix:"), let s = Knowledge.symptoms.first(where: { $0.id == String(r.dropFirst(4)) }) { activePlan = s.plan(current: s.culpritValue) }
        }
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

    /// Read-only device check: snapshot + findings.
    @MainActor func runCheck() async {
        guard !checking else { return }
        checking = true
        snapshot = await engine.snapshot()
        let f = await engine.check()
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(Motion.spring) { findings = f; lastCheck = Date(); checking = false }
    }

    /// Run a reviewed plan through the current engine and record a receipt.
    @MainActor func execute(_ plan: OperationPlan, dryRun: Bool, progress: @escaping @MainActor (OperationRunner.Stage) -> Void) async -> Receipt {
        let r = await OperationRunner.run(plan, engine: engine, dryRun: dryRun, receiptID: receipts.nextID, progress: progress)
        receipts.add(r)
        if !dryRun && !plan.undoOf.isEmpty && r.status != .failed { receipts.markRolledBack(plan.undoOf) }
        if !dryRun { await runCheck() }
        return r
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


/// Screens pushed inside the Lab tab.
enum LabRoute: Hashable {
    case diagnose, history
    case symptom(String)
    case receipt(Int)
}
