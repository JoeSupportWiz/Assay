import SwiftUI

@main
struct AssayApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView().environment(model) }
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
        .task { await model.refresh() }
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
                    case .scenes: NavigationStack { ScenesView() }
                    case .studio: NavigationStack { StudioView() }
                    case .lab: LabRoot()
                    case .more: NavigationStack { MoreView() }
                    }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .sheet(item: $model.activePlan) { plan in
            FixSheet(plan: plan)
                .presentationDetents([.large])
                .environment(\.theme, t)
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
                    case .symptom(let id): SymptomView(id: id)
                    case .receipt(let id): ReceiptView(id: id)
                    }
                }
        }
    }
}
