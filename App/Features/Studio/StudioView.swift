import SwiftUI

enum StudioModule: String, CaseIterable, Identifiable, Hashable {
    case gild, canvas, cards, alchemy, signet
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self { case .gild: "Review tweaks and presets"; case .canvas: "Inspect and replace wallpaper layers"; case .cards: "Design and export card art"; case .alchemy: "Ask about a device or project"; case .signet: "Inspect builds and prepare profiles" }
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
                            Image("fold-" + (m == .signet ? "signing" : m.rawValue)).renderingMode(.template).resizable().scaledToFit().frame(width: 24, height: 24).foregroundStyle(t.ink).frame(width: 40, height: 44).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title).font(.body.weight(.semibold)).foregroundStyle(t.ink)
                                Text(m.subtitle).font(.subheadline).foregroundStyle(t.ink2)
                            }

                        }
                    }
                }
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Studio")

    }
}
