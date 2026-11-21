import SwiftUI

enum StudioModule: String, CaseIterable, Identifiable, Hashable {
    case gild, canvas, cards, alchemy, signet
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var asset: String { self == .signet ? "fold-signing" : "fold-" + rawValue }
    var subtitle: String {
        switch self {
        case .gild: "Review presets"
        case .canvas: "Edit wallpaper layers"
        case .cards: "Design card art"
        case .alchemy: "Ask for AI advice"
        case .signet: "Inspect signed builds"
        }
    }
    var hue: ModuleHue {
        switch self {
        case .gild, .alchemy: .lilac
        case .canvas: .sky
        case .cards: .mint
        case .signet: .butter
        }
    }

    var tile: some View { AssayCraftToolTile(title: title, detail: subtitle, asset: asset, hue: hue) }
}

struct StudioView: View {
    @Environment(\.theme) private var t
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AssayCraftHeading(section: "Studio", title: "Studio", secondLine: "Art, presets & builds.")
                NavigationLink(value: StudioRoute.module(.alchemy)) { alchemyCover }
                    .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workshops").font(.title2.bold()).tracking(-0.6).foregroundStyle(t.ink)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize >= .xxLarge ? 1 : 2), spacing: 12) {
                        ForEach(StudioModule.allCases.filter { $0 != .alchemy }) { module in
                            NavigationLink(value: StudioRoute.module(module)) { module.tile }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 28)
        }
        .background(ThemedBackground()).navigationTitle("Studio")
        .navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .navigationBar)
    }

    /// An example on a printed prompt slip, not a generated reply or a provider status.
    private var alchemyCover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AssayCraftGlyph(asset: StudioModule.alchemy.asset)
                Text("Alchemy · AI advice").font(.headline)
            }.foregroundStyle(Palette.lilac)
            VStack(alignment: .leading, spacing: 4) {
                Text("EXAMPLE QUESTION").font(.caption.monospaced().weight(.semibold)).tracking(0.8)
                Text("Why is my clock stuck at 9:41?").font(.title.bold()).tracking(-0.7)
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) { Rectangle().fill(Palette.lilac).frame(width: 2) }
            HStack {
                Text("Open chat").font(.headline)
                Spacer()
                Image(systemName: "arrow.right").accessibilityHidden(true)
            }
            .foregroundStyle(Palette.ink).padding(.horizontal, 15).padding(.vertical, 10)
            .background(Palette.butter, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .foregroundStyle(Palette.paper).multilineTextAlignment(.leading).padding(20)
        .craftSurface(Palette.ink, radius: t.cardRadius, plane: true)
        .padding(.trailing, 5).padding(.bottom, 6)
        .accessibilityElement(children: .ignore).accessibilityLabel("Open Alchemy, AI advice chat")
        .accessibilityHint("Opens the chat without sending a question.")
    }
}
