import SwiftUI

@main
struct AssayApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = model.theme(for: scheme)
        ZStack {
            if model.hasOnboarded {
                MainShell().transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
            ToastHost()
        }
        .environment(\.theme, theme)
        .tint(theme.ink)
        .preferredColorScheme(preferredScheme)
        .animation(Motion.spring, value: model.hasOnboarded)
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

struct MainShell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            Group {
                switch model.selectedTab {
                case .home: NavigationStack { HomeView() }
                case .scenes: NavigationStack { ScenesView() }
                case .studio: NavigationStack { StudioView() }
                case .lab: NavigationStack { LabView() }
                case .more: NavigationStack { MoreView() }
                }
            }
            .id(model.selectedTab)
            .transition(.opacity)

            FloatingTabBar(selection: $model.selectedTab)
                .padding(.horizontal, 20).padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $model.showSearch) { SearchSheet() }
    }
}

/// Floating black pill (§2.2). Active tab morphs into an icon + label pill.
struct FloatingTabBar: View {
    @Environment(\.theme) private var t
    @Binding var selection: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    guard !active else { return }
                    Haptics.selection()
                    withAnimation(Motion.spring) { selection = tab }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: active ? tab.activeSymbol : tab.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        if active {
                            Text(tab.title).font(.system(size: 14, weight: .semibold)).fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .foregroundStyle(active ? t.tabActiveInk : t.tabInk)
                    .frame(height: 50)
                    .frame(maxWidth: active ? nil : .infinity)
                    .padding(.horizontal, active ? 16 : 0)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: min(t.pillRadius, 25), style: .continuous)
                                .fill(t.tabActive)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(9)
        .background(t.tabBar, in: RoundedRectangle(cornerRadius: min(t.pillRadius, 34), style: .continuous))
        .shadow(color: Color(hex: 0x111113, alpha: 0.25), radius: 20, y: 18)
    }
}

/// Top drop-in banner (§7.2). Auto-dismisses after 4 s.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    var body: some View {
        VStack {
            if let toast = model.toast {
                HStack(spacing: 12) {
                    Image(systemName: toast.symbol).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(toast.kind == .warning ? Palette.peachDeep : (toast.kind == .success ? Palette.mintDeep : Palette.skyDeep), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.ink)
                        if let s = toast.subtitle { Text(s).font(.system(size: 12.5)).foregroundStyle(t.ink2) }
                    }
                    Spacer()
                }
                .padding(12)
                .card(radius: 24)
                .shadow(color: .black.opacity(0.16), radius: 30, y: 20)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { withAnimation(Motion.snappy) { model.toast = nil } }
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(Motion.snappy) { if model.toast?.id == toast.id { model.toast = nil } }
                }
            }
            Spacer()
        }
        .padding(.top, 4)
        .animation(Motion.bouncy, value: model.toast)
    }
}
