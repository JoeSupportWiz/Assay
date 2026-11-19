import SwiftUI

@main
struct AssayApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup { AssayPrivacyGate { RootView().environment(model) }.task { await AssaySupporterStore.shared.start() } }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = model.theme(for: scheme)
        ZStack {
            if model.hasOnboarded { MainShell() } else { OnboardingView() }
            ToastHost()
        }
        .environment(\.theme, theme)
        .tint(theme.accentColor)
        .preferredColorScheme(preferredScheme)
        .onOpenURL { url in
            guard model.hasOnboarded, let target = AssaySurfaceRoute(url: url) else { return }
            switch target {
            case .clock: model.selectedTab = .lab; model.labPath = [.displayCheck]
            case .vault: model.selectedTab = .lab; model.labPath = [.fileVault]
            case .scenes: model.selectedTab = .scenes
            }
        }
        .onAppear { SceneLibraryStore.shared.attach(to: model) }
        .task(id: model.engineGeneration) { await model.refresh() }
    }

    private var preferredScheme: ColorScheme? {
        switch model.themeID {
        case .auto: nil
        case .dark, .wallpaper: .dark
        case .light, .millennium, .pinstripe: .light
        }
    }
}

extension Theme {
    /// Interactive tint for the native tab bar and controls.
    var accentColor: Color {
        switch id {
        case .millennium: Color(hex: 0x1C5FD6)
        case .pinstripe: Color(hex: 0x2D66D6)
        case .wallpaper: wallpaperColors.first ?? .white
        default: isDark ? Color(hex: 0xF5F4F0) : Palette.ink
        }
    }
    /// Selected tab tint, chosen to read on that theme's tab bar.
    var tabTint: Color {
        switch id {
        case .millennium: Color(hex: 0x205A31)
        case .pinstripe: Color(hex: 0x204F85)
        default: accentColor
        }
    }
}

struct MainShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Group {
                    switch tab {
                    case .home: NavigationStack { HomeView() }
                    case .scenes: ScenePlannerRoot()
                    case .studio: StudioRoot()
                    case .lab: LabRoot()
                    case .more: MoreRoot()
                    }
                }
                .tabItem { Label { Text(tab.title) } icon: { Image("fold-" + tab.rawValue).renderingMode(.template) } }
                .tag(tab)
            }
        }
        .tint(t.tabTint)
        .themedBars()
        .sheet(item: $model.activePlan) { plan in
            FixSheet(plan: plan)
                .presentationDetents([.large])
                .environment(\.theme, t)
        }
    }
}

/// Studio owns a path so Diagnose and Home can deep-link into Gild.
struct StudioRoot: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.studioPath) {
            StudioView()
                .navigationDestination(for: StudioRoute.self) { r in
                    switch r {
                    case .module(let m):
                        switch m {
                        case .gild: GildView()
                        case .alchemy: AlchemyRootView()
                        case .signet: SignetRootView()
                        case .canvas: CanvasRootView()
                        case .cards: CardArtRootView()
                        }
                    case .appleTeam: AppleTeamView()
                    case .presetFiles: GildPresetFilesView()
                    case .buildLibrary: SignetBuildLibrary()
                    case .signerPreflight: SignerPreflightView()
                    case .gild(let g): switch g { case .tweak(let id): TweakDetailView(id: id); case .preset(let id): PresetView(id: id) }
                    }
                }
        }
    }
}

/// Lab owns a navigation path so other tabs (Home) can deep-link into Diagnose and History.
struct LabRoot: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.labPath) {
            LabView()
                .navigationDestination(for: LabRoute.self) { route in
                    switch route {
                    case .diagnose: DiagnoseView()
                    case .history: HistoryView()
                    case .displayCheck: DisplayCheckView()
                    case .fileVault: FileVaultView()
                    case .bench: BenchView()
                    case .crashReview: CrashReviewView()
                    case .minis: MinisReviewView()
                    case .bluetooth: BluetoothRootView()
                    case .network: NetworkRootView()
                    case .symptom(let id): SymptomView(id: id)
                    case .receipt(let id): ReceiptView(id: id)
                    }
                }
        }
    }
}

struct MoreRoot: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.morePath) { MoreView().navigationDestination(for: MoreRoute.self) { route in
            switch route { case .lock: AssayPrivacyLockSettings(); case .supporter: SupporterView() }
        }}
    }
}

struct ScenePlannerRoot: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.scenePath) { SceneLibraryView().navigationDestination(for: PlannerRoute.self) { r in switch r { case .layout: SceneLayoutPlannerView(); case .transfer: SceneTransferView() } } }
    }
}
