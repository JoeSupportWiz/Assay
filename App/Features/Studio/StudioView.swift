import SwiftUI

enum StudioModule: String, CaseIterable, Identifiable, Hashable {
    case gild, canvas, cards, alchemy, signet
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .gild: "Customise"; case .canvas: "Wallpapers"; case .cards: "Wallet visuals"
        case .alchemy: "AI workshop"; case .signet: "Signing"
        }
    }
    var symbol: String {
        switch self {
        case .gild: "slider.horizontal.3"; case .canvas: "photo.artframe"; case .cards: "creditcard"
        case .alchemy: "sparkles"; case .signet: "seal"
        }
    }
    var hue: ModuleHue {
        switch self { case .gild: .lilac; case .canvas: .sky; case .cards: .mint; case .alchemy: .lilac; case .signet: .butter }
    }
    var blurb: String {
        switch self {
        case .gild: "Tweak catalogue with safety tiers, presets, compatibility for your exact build, and a custom builder."
        case .canvas: "Poster and .tendies projects: layers, Lock → Unlock timeline, validation, preview and export."
        case .cards: "Card art for Wallet passes and previews. Visual only — Assay never touches payment data."
        case .alchemy: "Describe an asset; your chosen AI drafts it; you edit, compare before/after and approve."
        case .signet: "Developer account, per-target bundle IDs, entitlements, profiles, expiry and guided renewal."
        }
    }
    var roadmap: String {
        switch self { case .gild: "Phase 2"; case .canvas: "Phase 4.3"; case .cards: "Phase 4.4"; case .alchemy: "Phase 5"; case .signet: "Phase 6" }
    }
    @ViewBuilder var destination: some View { ModuleComingView(module: self) }
}

struct StudioView: View {
    @Environment(\.theme) private var t
    var body: some View {
        Screen(title: "Studio", subtitle: "Make it yours — tweaks, wallpapers, cards, AI and signing.") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(StudioModule.allCases.enumerated()), id: \.element) { i, m in
                    NavigationLink(value: m) { ModuleTile(module: m, index: i).frame(maxWidth: .infinity) }
                        .buttonStyle(PressStyle()).rise(i + 1)
                }
            }.padding(.top, 20)
        }
        .navigationDestination(for: StudioModule.self) { $0.destination }
    }
}

/// Honest placeholder for a module whose slice hasn't landed yet. Shows what it will do, nothing fake.
struct ModuleComingView: View {
    @Environment(\.theme) private var t
    let module: StudioModule
    var body: some View {
        Screen(title: module.title, subtitle: module.subtitle, showsBack: true) {
            VStack(alignment: .leading, spacing: 16) {
                GlyphTile(symbol: module.symbol, hue: module.hue, size: 120).floating(0).frame(maxWidth: .infinity).padding(.vertical, 24)
                TwoToneTitle(line1: "Coming in \(module.roadmap),", line2: "built feature by feature.", size: 26)
                Text(module.blurb).font(.system(size: 15)).foregroundStyle(t.ink2)
                HStack { Tag(style: .neutral, text: "Not live yet"); Tag(style: .neutral, text: module.roadmap) }
            }
            .padding(.top, 8)
            .rise(1)
        }
    }
}

// MARK: - Scenes landing (Phase 4.1)

struct ScenesView: View {
    @Environment(\.theme) private var t
    @State private var recipe = "Work"
    private let recipes = ["Work", "Minimal", "One-page", "Colour-flow", "Sleep", "Travel", "Research"]
    var body: some View {
        Screen(title: "Scenes", subtitle: "Wallpaper, layout, widgets and Shortcuts, saved together.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recipes, id: \.self) { r in
                        Button { Haptics.selection(); withAnimation(Motion.snappy) { recipe = r } } label: {
                            Text(r).font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(recipe == r ? t.onPrimary : t.ink)
                                .padding(.horizontal, 15).frame(height: 36)
                                .background(recipe == r ? t.primary : AnyShapeStyle(t.card), in: Capsule())
                        }.buttonStyle(PressStyle())
                    }
                }.padding(.horizontal, 20)
            }.padding(.horizontal, -20).padding(.top, 18).rise(1)

            HStack(alignment: .top, spacing: 14) {
                ScenePreview(palette: .dusk).frame(width: 150, height: 268)
                VStack(alignment: .leading, spacing: 8) {
                    Tag(style: .neutral, text: "Preview")
                    Text("\(recipe) · Dusk").font(Typo.display(22, .bold, t)).foregroundStyle(t.ink)
                    ForEach([["Wallpaper", "Dusk 02"], ["Layout", "1 page"], ["Widgets", "3"], ["Shortcuts", "2"], ["Focus", recipe]], id: \.self) { kv in
                        HStack { Text(kv[0]).foregroundStyle(t.ink2); Spacer(); Text(kv[1]).fontWeight(.semibold).foregroundStyle(t.ink) }.font(.system(size: 13.5))
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14).card().padding(.top, 16).rise(2)

            VStack(alignment: .leading, spacing: 8) {
                HStack { Tag(style: .inferred(nil)); Tag(style: .neutral, text: "Phase 4.1") }
                Text("Composer, consistency check and guided apply land next.").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                Text("iOS doesn't let apps rearrange your Home Screen, so Assay will guide each move and only mark it done when you confirm.")
                    .font(.system(size: 13.5)).foregroundStyle(t.ink2)
            }.padding(18).card().padding(.top, 12).rise(3)
        }
    }
}

/// Mini Home Screen: wallpaper, glass widget, tinted app grid, dock.
struct ScenePreview: View {
    let palette: WallpaperPalette
    var body: some View {
        let c = palette.colors
        ZStack {
            LinearGradient(colors: [c[1], c[4]], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [c[0], .clear], center: UnitPoint(x: 0.25, y: 0.2), startRadius: 0, endRadius: 140)
            RadialGradient(colors: [c[3], .clear], center: UnitPoint(x: 0.3, y: 0.95), startRadius: 0, endRadius: 160)
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).frame(height: 62).overlay(alignment: .topLeading) {
                    Text("94").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).padding(10)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(0..<12) { i in RoundedRectangle(cornerRadius: 7).fill(c[i % 4].opacity(0.85)).aspectRatio(1, contentMode: .fit) }
                }
                Spacer()
                RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).frame(height: 40)
            }.padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: c[3].opacity(0.3), radius: 18, y: 14)
    }
}
