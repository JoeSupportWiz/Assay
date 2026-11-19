import SwiftUI

private enum AssayTab: String, CaseIterable, Identifiable {
    case home = "Home", scenes = "Scenes", studio = "Studio", lab = "Lab", more = "More"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .scenes: "square.3.layers.3d"
        case .studio: "slider.horizontal.3"
        case .lab: "waveform.path.ecg.rectangle"
        case .more: "ellipsis"
        }
    }
}

struct AssayRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: AssayTab = .home
    @State private var showSearch = false
    @Namespace private var tabAnimation

    private var theme: AssayTheme { colorScheme == .dark ? .dark : .light }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .home: AssayHomeView(theme: theme, openSearch: { showSearch = true })
                case .scenes: ModuleLandingView(title: "Scenes", subtitle: "A whole feeling, in one tap.", symbol: "square.3.layers.3d", detail: "Pair a wallpaper with a Home Screen layout, widgets and Shortcuts.", accent: theme.tiles[0], theme: theme)
                case .studio: ModuleLandingView(title: "Studio", subtitle: "Make it yours.", symbol: "slider.horizontal.3", detail: "Tweaks, wallpapers, card visuals and AI-assisted creations.", accent: theme.tiles[1], theme: theme)
                case .lab: ModuleLandingView(title: "Device Lab", subtitle: "Know what is really happening.", symbol: "waveform.path.ecg.rectangle", detail: "Diagnostics, signing, backups, Bluetooth and network tools.", accent: theme.tiles[2], theme: theme)
                case .more: ModuleLandingView(title: "More", subtitle: "Your controls, your rules.", symbol: "ellipsis", detail: "Appearance, AI providers, privacy, updates and operation history.", accent: theme.tiles[0], theme: theme)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $tab, theme: theme, namespace: tabAnimation)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        }
        .sheet(isPresented: $showSearch) { SearchPlaceholder(theme: theme) }
        .tint(theme.ink)
    }
}

private struct AssayHomeView: View {
    let theme: AssayTheme
    let openSearch: () -> Void
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image("AssayLockup")
                        .resizable().scaledToFit().frame(width: 112, height: 34).accessibilityLabel("Assay")
                    Spacer()
                    Button(action: openSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(theme.onPrimary)
                            .background(theme.primary, in: Circle())
                    }.buttonStyle(PressStyle()).accessibilityLabel("Search Assay")
                }.padding(.top, 12).rise(0)

                Text("Hey, Joe,")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .tracking(-1.2).foregroundStyle(theme.ink).padding(.top, 24).rise(1)
                Text("what are we making?")
                    .font(.system(size: 31, weight: .bold, design: .serif))
                    .tracking(-1.1).foregroundStyle(theme.ink3).padding(.top, -3).rise(2)

                HStack(spacing: 8) {
                    Circle().fill(Color(hex: 0x38C98A)).frame(width: 9, height: 9)
                    Text("Design preview · device not connected")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.ink)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(theme.card, in: Capsule()).padding(.top, 18).rise(3)

                Button(action: openSearch) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .medium))
                        Text("Search tweaks, profiles, assets…").font(.system(size: 15))
                        Spacer()
                        Image(systemName: "sparkle.magnifyingglass").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.ink).frame(width: 38, height: 38).background(theme.soft, in: Circle())
                    }.foregroundStyle(theme.ink3).padding(.leading, 17).padding(.trailing, 7)
                        .frame(height: 54).background(theme.card, in: Capsule())
                }.buttonStyle(PressStyle()).padding(.top, 16).rise(4)

                HStack(spacing: 12) {
                    HealthPreviewCard(theme: theme)
                    BackupPreviewCard(theme: theme)
                }.frame(height: 154).padding(.top, 20).rise(5)

                HStack(alignment: .firstTextBaseline) {
                    Text("Studio").font(.system(size: 22, weight: .bold)).foregroundStyle(theme.ink)
                    Spacer()
                    Text("Explore all  →").font(.system(size: 13, weight: .medium)).foregroundStyle(theme.ink2)
                }.padding(.top, 27).rise(6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StudioTile(title: "Gild", detail: "Tweak catalogue", symbol: "slider.horizontal.3", colour: Color(hex: 0xDCD1FF), theme: theme)
                        StudioTile(title: "Canvas", detail: "Wallpapers", symbol: "photo.artframe", colour: Color(hex: 0xC4E6FF), theme: theme)
                        StudioTile(title: "Alchemy", detail: "AI workshop", symbol: "sparkles", colour: Color(hex: 0xBDF3D7), theme: theme)
                        StudioTile(title: "Signet", detail: "App signing", symbol: "seal", colour: Color(hex: 0xFFE58A), theme: theme)
                    }.padding(.vertical, 12)
                }.padding(.horizontal, -20).padding(.leading, 20).padding(.top, 4).rise(7)

                HStack {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 19)).foregroundStyle(Color(hex: 0xFF7A3D))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Developer certificate").font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.ink)
                        Text("Connect a developer account to check status")
                            .font(.system(size: 12)).foregroundStyle(theme.ink2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink3)
                }.padding(15).background(theme.card, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 4).padding(.bottom, 24).rise(8)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct HealthPreviewCard: View {
    let theme: AssayTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Device check").font(.system(size: 16, weight: .bold, design: .serif)).foregroundStyle(.white)
            Spacer()
            Text("Ready when\nyou are").font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(.white)
            Text("Run a quick check").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)).padding(.top, 5)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 25).fill(Color(hex: 0x111113))
                    Circle().fill(Color(hex: 0xBDF3D7).opacity(0.13)).frame(width: 112).blur(radius: 22).offset(x: 24, y: -24)
                }
            }
    }
}

private struct BackupPreviewCard: View {
    let theme: AssayTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Vault").font(.system(size: 16, weight: .bold, design: .serif)); Spacer(); Text("READY").font(.system(size: 9, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 5).background(.black.opacity(0.07), in: Capsule()) }
            Spacer()
            Text("Backup health").font(.system(size: 18, weight: .bold, design: .serif))
            Text("No baseline yet").font(.system(size: 11)).foregroundStyle(theme.ink2).padding(.top, 3)
            Capsule().fill(Color.black.opacity(0.10)).frame(height: 5).overlay(alignment: .leading) { Capsule().fill(Color.black).frame(width: 0, height: 5) }.padding(.top, 12)
        }.foregroundStyle(theme.ink).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xFFE58A), in: RoundedRectangle(cornerRadius: 25))
    }
}

private struct StudioTile: View {
    let title, detail, symbol: String
    let colour: Color
    let theme: AssayTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(theme.ink)
                .frame(width: 47, height: 47).background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 18)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(theme.ink)
                    Text(detail).font(.system(size: 11)).foregroundStyle(theme.ink2)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(.black, in: Circle())
            }
        }.padding(14).frame(width: 160, height: 148).background(colour, in: RoundedRectangle(cornerRadius: 23))
            .buttonStyle(PressStyle())
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: AssayTab
    let theme: AssayTheme
    let namespace: Namespace.ID
    var body: some View {
        HStack(spacing: 3) {
            ForEach(AssayTab.allCases) { item in
                Button { withAnimation(AssayMotion.spring) { selection = item } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol).font(.system(size: 19, weight: .semibold)).frame(width: 26)
                        if selection == item { Text(item.rawValue).font(.system(size: 13, weight: .semibold)).matchedGeometryEffect(id: "label", in: namespace) }
                    }
                    .foregroundStyle(selection == item ? theme.tabActiveInk : Color.white.opacity(0.66))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background {
                        if selection == item {
                            Capsule().fill(theme.tabActive).matchedGeometryEffect(id: "active", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }.buttonStyle(PressStyle()).accessibilityLabel(item.rawValue)
            }
        }
        .padding(8).background(theme.tabBar, in: Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.18), radius: 22, x: 0, y: 10)
    }
    @Environment(\.colorScheme) private var colorScheme
}

private struct ModuleLandingView: View {
    let title, subtitle, symbol, detail: String
    let accent: Color
    let theme: AssayTheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image("AssayLockup").resizable().scaledToFit().frame(width: 112, height: 34); Spacer(); Image(systemName: "ellipsis.circle.fill").font(.system(size: 28)).foregroundStyle(theme.ink) }
                    .padding(.top, 12)
                Text(title).font(.system(size: 34, weight: .bold, design: .serif)).tracking(-1).foregroundStyle(theme.ink).padding(.top, 24)
                Text(subtitle).font(.system(size: 25, weight: .bold, design: .serif)).foregroundStyle(theme.ink2)
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: symbol).font(.system(size: 32, weight: .medium)).foregroundStyle(theme.ink)
                        .frame(width: 68, height: 68).background(accent, in: RoundedRectangle(cornerRadius: 23))
                    Text("Coming into focus").font(.system(size: 24, weight: .bold, design: .serif)).foregroundStyle(theme.ink)
                    Text(detail).font(.system(size: 15)).foregroundStyle(theme.ink2)
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(theme.card, in: RoundedRectangle(cornerRadius: 28))
                Text("This design preview uses no device data yet.").font(.system(size: 12)).foregroundStyle(theme.ink3).padding(.top, 4)
            }.padding(.horizontal, 20).padding(.bottom, 32)
        }
    }
}

private struct SearchPlaceholder: View {
    let theme: AssayTheme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(theme.ink2); TextField("Tweaks, profiles, assets…", text: $query).font(.system(size: 16)) }
                    .padding(15).background(theme.soft, in: Capsule())
                Text("Search will span tweaks, findings, signing targets, assets and actions.").font(.system(size: 14)).foregroundStyle(theme.ink2)
                Spacer()
            }.padding(20).background(theme.bg.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(theme.ink) } }
                .navigationTitle("Search Assay").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

#Preview { AssayRootView() }
