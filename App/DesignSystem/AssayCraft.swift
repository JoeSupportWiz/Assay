import SwiftUI

/// The catalog is the single source for the mark and all module glyphs.
struct AssayCraftGlyph: View {
    let asset: String
    var size: CGFloat = 24

    var body: some View {
        Image(asset).renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct AssayCraftHeading: View {
    @Environment(\.theme) private var t
    let section: String, title: String, secondLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                AssayCraftGlyph(asset: "fold-symbol", size: 34)
                Text("Assay").font(.headline.weight(.heavy)).tracking(-0.6)
                Spacer()
                Text(section.uppercased()).font(.caption.monospaced().weight(.semibold)).tracking(1.1)
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                Text(secondLine).foregroundStyle(t.ink2)
            }
            .font(.largeTitle.weight(.bold)).tracking(-1.1)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// No optical shadow: only the featured surface gets a second, offset sheet.
    func craftSurface(_ fill: Color, radius: CGFloat = 22, plane: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(fill, in: shape)
            .overlay { shape.strokeBorder(Palette.ink.opacity(0.07), lineWidth: 1).allowsHitTesting(false) }
            .background { if plane { shape.fill(Palette.lilac).offset(x: 5, y: 6) } }
    }
}

/// One paper tile has one destination. Its glyph and arrow are not separate controls.
struct AssayCraftToolTile: View {
    @Environment(\.theme) private var t
    let title: String, detail: String, asset: String, hue: ModuleHue

    var body: some View {
        let darkInk = !t.isDark || hue == .butter
        let ink = darkInk ? Palette.ink : Palette.paper
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                AssayCraftGlyph(asset: asset).frame(width: 38, height: 38)
                    .background(ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.forward").font(.footnote.weight(.semibold)).accessibilityHidden(true)
            }.padding(.bottom, 10)
            Text(title).font(.title3.bold()).tracking(-0.5)
            Text(detail).font(.subheadline)
        }
        .foregroundStyle(ink).multilineTextAlignment(.leading)
        .padding(15).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .craftSurface(t.isDark ? hue.darkTile : hue.tile, radius: t.tileRadius)
        .contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}
