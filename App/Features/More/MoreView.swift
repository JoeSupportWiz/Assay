import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        Screen(title: "More", subtitle: "Your controls, your rules.") {
            VStack(spacing: 0) {
                NavigationLink { AppearanceView() } label: {
                    Row(icon: "paintpalette", hue: .peach, title: "Appearance", subtitle: model.themeID.title) { chevron }
                }
                Divider().padding(.leading, 68)
                NavigationLink { EngineSettingsView() } label: {
                    Row(icon: model.engineMode?.symbol ?? "cpu", hue: .sky, title: "Engine", subtitle: model.engineMode?.title ?? "Not chosen") { chevron }
                }
            }.buttonStyle(.plain).card().padding(.top, 20).rise(1)

            VStack(spacing: 0) {
                @Bindable var model = model
                Row(icon: "chevron.left.forwardslash.chevron.right", hue: .lilac, title: "Expert mode", subtitle: "Show plist keys, bundle IDs and raw values") {
                    Toggle("", isOn: $model.expertMode).labelsHidden().tint(Palette.mintDeep)
                }
            }.card().padding(.top, 12).rise(2)

            SectionHeader(title: "Coming up").rise(3)
            VStack(spacing: 0) {
                ForEach(Array(Self.upcoming.enumerated()), id: \.offset) { i, item in
                    Row(icon: item.symbol, hue: item.hue, title: item.title, subtitle: item.subtitle) { Tag(style: .neutral, text: item.phase) }
                    if i < Self.upcoming.count - 1 { Divider().padding(.leading, 68) }
                }
            }.card().rise(4)

            Text("Assay · working name · \(Bundle.main.shortVersion)\nProprietary · not affiliated with Apple")
                .font(.system(size: 12)).foregroundStyle(t.ink2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.top, 28)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink3)
    }

    private struct Upcoming { let symbol: String; let hue: ModuleHue; let title: String; let subtitle: String; let phase: String }
    private static let upcoming: [Upcoming] = [
        .init(symbol: "brain", hue: .lilac, title: "AI providers", subtitle: "Minis · hosted · Ollama", phase: "5.1"),
        .init(symbol: "hand.raised", hue: .mint, title: "Permissions & privacy", subtitle: "What Assay can see and why", phase: "Phase 8"),
        .init(symbol: "arrow.down.circle", hue: .sky, title: "Updates", subtitle: "App and catalogue", phase: "2.5"),
        .init(symbol: "star", hue: .butter, title: "Assay Pro", subtitle: "Optional supporter purchase", phase: "Phase 9"),
    ]
}

extension Bundle {
    var shortVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - Appearance (§8.8)

struct AppearanceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    private let grid: [ThemeID] = [.light, .dark, .millennium, .pinstripe]

    var body: some View {
        Screen(title: "Appearance", subtitle: "Pick a mode and a theme.", showsBack: true) {
            ModeControl().padding(.top, 18).rise(1)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(grid) { id in ThemeCard(id: id) }
            }.padding(.top, 16).rise(2)

            ThemeCard(id: .wallpaper, wide: true).padding(.top, 12).rise(3)
            Text("iOS doesn't share your wallpaper with apps, so colours come from Canvas or a photo you pick. Photo matching arrives with Palette Lab (4.2).")
                .font(.system(size: 12.5)).foregroundStyle(t.ink2).padding(.top, 10).rise(4)
        }
    }
}

private struct ModeControl: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @Namespace private var ns
    private let modes: [ThemeID] = [.auto, .light, .dark]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes) { m in
                let on = model.themeID == m
                Button { Haptics.selection(); withAnimation(Motion.spring) { model.themeID = m } } label: {
                    Text(m.title).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(on ? t.bg : t.ink)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background { if on { Capsule().fill(t.ink).matchedGeometryEffect(id: "knob", in: ns) } }
                }.buttonStyle(.plain)
            }
        }
        .padding(4).card(radius: 23)
    }
}

private struct ThemeCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let id: ThemeID
    var wide = false
    var body: some View {
        let selected = model.themeID == id
        let preview: Theme = switch id {
        case .dark: .dark; case .millennium: .millennium; case .pinstripe: .pinstripe
        case .wallpaper: .wallpaper(model.wallpaperPalette); default: .light
        }
        Button {
            Haptics.tap(.soft)
            withAnimation(Motion.spring) { model.themeID = id }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                MiniPreview(theme: preview).frame(height: wide ? 120 : 150)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(id.title).font(.system(size: 15, weight: .bold)).foregroundStyle(t.ink)
                        Text(id.subtitle).font(.system(size: 12)).foregroundStyle(t.ink2).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                        .foregroundStyle(selected ? Palette.mintDeep : t.ink3)
                        .scaleEffect(selected ? 1 : 0.85)
                }
            }
            .padding(10)
            .card(radius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(t.ink, lineWidth: selected ? 2.5 : 0))
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(id.title) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A miniature of Home in the given theme.
private struct MiniPreview: View {
    let theme: Theme
    var body: some View {
        ZStack(alignment: .topLeading) {
            ThemedBackground()
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(theme.ink).frame(width: 46, height: 6)
                RoundedRectangle(cornerRadius: 3).fill(theme.ink3).frame(width: 70, height: 6)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: theme.cardRadius / 3, style: .continuous).fill(theme.hero)
                    RoundedRectangle(cornerRadius: theme.cardRadius / 3, style: .continuous).fill(theme.accent)
                }.frame(height: 46)
                HStack(spacing: 6) {
                    ForEach([ModuleHue.lilac, .sky, .mint], id: \.self) { h in
                        RoundedRectangle(cornerRadius: theme.tileRadius / 3, style: .continuous).fill(theme.tile(h))
                    }
                }.frame(height: 26)
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: min(theme.pillRadius, 9), style: .continuous).fill(theme.tabBar).frame(height: 16)
            }.padding(10)
        }
        .environment(\.theme, theme)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Engine settings

struct EngineSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var availability: EngineAvailability?

    var body: some View {
        Screen(title: "Engine", subtitle: "How Assay reaches your iPhone.", showsBack: true) {
            VStack(spacing: 10) {
                ForEach(EngineMode.allCases) { mode in
                    let on = model.engineMode == mode
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) { model.engineMode = mode }
                        Task { await model.refresh(); availability = await model.engine.availability() }
                    } label: {
                        HStack(spacing: 14) {
                            GlyphTile(symbol: mode.symbol, hue: mode == .mac ? .lilac : (mode == .iphone ? .mint : .butter), size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title).font(.system(size: 16, weight: .bold)).foregroundStyle(t.ink)
                                Text(detail(mode)).font(.system(size: 12.5)).foregroundStyle(t.ink2)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? Palette.mintDeep : t.ink3)
                        }
                        .padding(14).card(radius: 22)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(t.ink, lineWidth: on ? 2 : 0))
                    }.buttonStyle(PressStyle())
                }
            }.padding(.top, 18).rise(1)

            if let a = availability {
                VStack(alignment: .leading, spacing: 8) {
                    switch a {
                    case .ready: Tag(style: .reversible, text: "Ready"); Text("This engine can reach the device.").foregroundStyle(t.ink)
                    case .needsSetup(let s): Tag(style: .caution, text: "Needs setup"); Text(s).foregroundStyle(t.ink)
                    case .unavailable(let s): Tag(style: .experimental, text: "Unavailable"); Text(s).foregroundStyle(t.ink)
                    }
                }.font(.system(size: 14)).padding(16).frame(maxWidth: .infinity, alignment: .leading).card().padding(.top, 14).rise(2)
            }
        }
        .task { availability = await model.engine.availability() }
    }

    private func detail(_ m: EngineMode) -> String {
        switch m {
        case .mac: "Fastest · USB · runs while locked"
        case .iphone: "Most private · everything on this phone"
        case .demo: "Sample device · changes nothing"
        }
    }
}
