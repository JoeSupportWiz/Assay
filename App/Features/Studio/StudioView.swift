import SwiftUI

enum StudioModule: String, CaseIterable, Identifiable, Hashable {
    case gild, canvas, cards, alchemy, signet
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self { case .gild: "Customise"; case .canvas: "Wallpapers"; case .cards: "Wallet visuals"; case .alchemy: "AI workshop"; case .signet: "Signing" }
    }
    var symbol: String {
        switch self { case .gild: "slider.horizontal.3"; case .canvas: "photo.artframe"; case .cards: "creditcard"; case .alchemy: "sparkles"; case .signet: "signature" }
    }
    var hue: ModuleHue { switch self { case .gild: .lilac; case .canvas: .sky; case .cards: .mint; case .alchemy: .lilac; case .signet: .butter } }
    var blurb: String {
        switch self {
        case .gild: "Tweaks with safety tiers, presets, compatibility for your exact build, and a custom builder."
        case .canvas: "Poster and .tendies projects: layers, lock-to-unlock timeline, validation, preview and export."
        case .cards: "Card art for Wallet passes. Visual only — Assay never touches payment data."
        case .alchemy: "Describe an asset; your chosen AI drafts it; you edit, compare and approve."
        case .signet: "Developer account, per-target profiles and entitlements, expiry and guided renewal."
        }
    }
    var phase: String { switch self { case .gild: "Live"; case .canvas: "Projects"; case .cards: "Art editor"; case .alchemy: "Chat"; case .signet: "Inspector" } }
}

struct StudioView: View {
    @Environment(\.theme) private var t
    var body: some View {
        List {
            Section {
                ForEach(StudioModule.allCases) { m in
                    NavigationLink(value: StudioRoute.module(m)) {
                        HStack(spacing: 12) {
                            IconTile(symbol: m.symbol, hue: m.hue, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title).font(.system(size: 17, weight: .medium)).foregroundStyle(t.ink)
                                Text(m.subtitle).font(.system(size: 13)).foregroundStyle(t.ink2)
                            }
                            Spacer(); Tag(style: .neutral, text: m.phase)
                        }
                    }
                }
            } footer: { Text("Built one at a time. Each lands with its own tests and screenshots.") }.rowCard()
        }
        .themedList()
        .navigationTitle("Studio")

    }
}

struct ModuleComingView: View {
    @Environment(\.theme) private var t
    let module: StudioModule
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    IconTile(symbol: module.symbol, hue: module.hue, size: 44)
                    Text(module.title).font(.system(size: 24, weight: .bold)).foregroundStyle(t.ink)
                    Text(module.blurb).foregroundStyle(t.ink2)
                }.padding(.vertical, 4)
            }.rowCard()
            Section { LabeledContent("Status") { Text("Not built yet") }; LabeledContent("Planned") { Text(module.phase) } }.rowCard()
        }
        .themedList()
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScenesView: View {
    @Environment(\.theme) private var t
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    IconTile(symbol: "square.2.layers.3d", hue: .lilac, size: 44)
                    Text("Scenes").font(.system(size: 24, weight: .bold)).foregroundStyle(t.ink)
                    Text("Wallpaper, Home Screen layout, widgets and Shortcuts, saved together.").foregroundStyle(t.ink2)
                }.padding(.vertical, 4)
            }.rowCard()
            Section("Planned recipes") {
                ForEach(["Work", "Minimal", "One page", "Colour flow", "Sleep", "Travel", "Research"], id: \.self) { Text($0).foregroundStyle(t.ink2) }
            }.rowCard()
            Section {
                Text("iOS doesn't let apps rearrange the Home Screen, so Assay will guide each move and only mark it done when you confirm.")
                    .font(.system(size: 14)).foregroundStyle(t.ink2)
            } header: { Text("How it will work") } footer: { Text("Planned for Phase 4.") }.rowCard()
        }
        .themedList()
        .navigationTitle("Scenes")
    }
}
