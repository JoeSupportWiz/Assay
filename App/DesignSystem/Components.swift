import SwiftUI

// MARK: - Fold mark (drawn from brand/svg/symbol.svg, viewBox 17…67 × 5.5…77)

struct FoldMark: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 50, sy = r.height / 71.5
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + (x - 17) * sx, y: r.minY + (y - 5.5) * sy) }
        var path = Path()
        // Upper plane
        path.move(to: p(17, 25.5)); path.addQuadCurve(to: p(19.4, 21.4), control: p(17, 22.8))
        path.addLine(to: p(42.5, 8.1)); path.addQuadCurve(to: p(47, 10.8), control: p(47, 5.5))
        path.addLine(to: p(47, 24.2)); path.addLine(to: p(28.2, 35.1)); path.addQuadCurve(to: p(25.5, 39.7), control: p(25.5, 36.7))
        path.addLine(to: p(25.5, 51.8)); path.addQuadCurve(to: p(23.1, 56), control: p(25.5, 54.6))
        path.addLine(to: p(17, 59.5)); path.closeSubpath()
        // Centre plane
        path.move(to: p(34, 34.8)); path.addQuadCurve(to: p(36.4, 30.7), control: p(34, 32.1))
        path.addLine(to: p(62.6, 15.6)); path.addQuadCurve(to: p(67, 18.3), control: p(67, 13.1))
        path.addLine(to: p(67, 44.4)); path.addQuadCurve(to: p(64.6, 48.5), control: p(67, 47.1))
        path.addLine(to: p(38.4, 63.6)); path.addQuadCurve(to: p(34, 60.9), control: p(34, 66.1)); path.closeSubpath()
        // Lower plane
        path.move(to: p(34, 57.4)); path.addLine(to: p(54.8, 45.4)); path.addQuadCurve(to: p(59.8, 45.7), control: p(57.4, 43.9))
        path.addLine(to: p(67, 51)); path.addLine(to: p(67, 60.2)); path.addLine(to: p(41.8, 74.7))
        path.addQuadCurve(to: p(37.4, 72), control: p(37.4, 77.2)); path.addLine(to: p(37.4, 61.8))
        path.addQuadCurve(to: p(34, 57.4), control: p(37.4, 59.2)); path.closeSubpath()
        return path
    }
}

struct Wordmark: View {
    @Environment(\.theme) private var t
    var size: CGFloat = 19
    var body: some View {
        HStack(spacing: size * 0.34) {
            FoldMark().fill(t.ink).frame(width: size * 0.98, height: size * 1.4)
            Text("Assay").font(.system(size: size, weight: .heavy)).tracking(-size * 0.05).foregroundStyle(t.ink)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Assay")
    }
}

// MARK: - Backgrounds

struct ThemedBackground: View {
    @Environment(\.theme) private var t
    var body: some View {
        switch t.id {
        case .pinstripe:
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xC5CCD4)))
                var x: CGFloat = 5
                while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(Color(hex: 0xCBD2D8))); x += 7 }
            }.ignoresSafeArea()
        case .wallpaper:
            let c = t.wallpaperColors.count == 5 ? t.wallpaperColors : WallpaperPalette.dusk.colors
            ZStack {
                LinearGradient(colors: [c[1], c[4]], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [c[0].opacity(0.9), .clear], center: UnitPoint(x: 0.25, y: 0.18), startRadius: 0, endRadius: 320)
                RadialGradient(colors: [c[3].opacity(0.9), .clear], center: UnitPoint(x: 0.3, y: 0.95), startRadius: 0, endRadius: 380)
            }.ignoresSafeArea()
        default:
            t.bg.ignoresSafeArea()
        }
    }
}

// MARK: - Cards

struct CardBackground: ViewModifier {
    @Environment(\.theme) private var t
    var radius: CGFloat? = nil
    var fill: AnyShapeStyle? = nil
    func body(content: Content) -> some View {
        let r = radius ?? t.cardRadius
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        content
            .background {
                if t.glass && fill == nil {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(Color.white.opacity(0.06)))
                } else {
                    shape.fill(fill ?? AnyShapeStyle(t.card))
                }
            }
            .overlay { if let b = t.cardBorder { shape.strokeBorder(b, lineWidth: 1) } }
            .clipShape(shape)
    }
}

extension View {
    func card(radius: CGFloat? = nil, fill: AnyShapeStyle? = nil) -> some View { modifier(CardBackground(radius: radius, fill: fill)) }
}

// MARK: - Buttons (§6.1)

struct PillButton: View {
    enum Kind { case primary, secondary, compact, destructive }
    @Environment(\.theme) private var t
    let title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var loading = false
    let action: () -> Void

    var body: some View {
        Button {
            if kind == .primary { Haptics.tap() }
            action()
        } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(fg) }
                Text(title).font(.system(size: kind == .compact ? 14 : 16, weight: .semibold))
                if let icon, !loading { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
            }
            .foregroundStyle(fg)
            .padding(.horizontal, kind == .compact ? 16 : 22)
            .frame(maxWidth: kind == .compact ? nil : .infinity)
            .frame(height: kind == .compact ? 38 : 54)
            .background(bg, in: RoundedRectangle(cornerRadius: min(t.pillRadius, kind == .compact ? 19 : 27), style: .continuous))
            .overlay {
                if kind == .secondary, let b = t.cardBorder {
                    RoundedRectangle(cornerRadius: min(t.pillRadius, 27), style: .continuous).strokeBorder(b, lineWidth: 1)
                }
            }
        }
        .buttonStyle(PressStyle())
        .disabled(loading)
    }

    private var fg: Color {
        switch kind { case .primary, .compact: t.onPrimary; case .secondary: t.ink; case .destructive: .white }
    }
    private var bg: AnyShapeStyle {
        switch kind {
        case .primary, .compact: t.primary
        case .secondary: t.glass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(t.card)
        case .destructive: AnyShapeStyle(Palette.destructive)
        }
    }
}

struct IconCircle: View {
    @Environment(\.theme) private var t
    let systemName: String
    var filled = true
    var size: CGFloat = 46
    var badge = false
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(filled ? t.onPrimary : t.ink)
                .frame(width: size, height: size)
                .background(filled ? t.primary : AnyShapeStyle(t.card), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if badge { Circle().fill(Palette.peachDeep).frame(width: 10, height: 10).offset(x: -6, y: 6) }
                }
        }.buttonStyle(PressStyle())
    }
}

// MARK: - Tags (§3.3)

enum TagStyle {
    case reversible, caution, experimental, observed, inferred(Int?), unknown, live, neutral, demo, locked
    var label: String {
        switch self {
        case .reversible: "Reversible"; case .caution: "Caution"; case .experimental: "Experimental"
        case .observed: "Observed"
        case .inferred(let p): p.map { "Inferred · \($0)%" } ?? "Inferred"
        case .unknown: "Unknown"; case .live: "Live"; case .neutral: ""; case .demo: "Demo"; case .locked: "Not on this iOS"
        }
    }
    var colors: (Color, Color)? {
        switch self {
        case .reversible: (Palette.mint, Color(hex: 0x0D5C37))
        case .caution: (Palette.butter, Color(hex: 0x5A4300))
        case .experimental: (Palette.peach, Color(hex: 0x8A3300))
        case .observed: (Palette.sky, Color(hex: 0x0A4A85))
        case .inferred: (Palette.lilac, Color(hex: 0x3A1FA8))
        case .live: (Palette.butter, Palette.ink)
        case .demo: (Color(hex: 0xECEBE6), Color(hex: 0x4A4A50))
        case .unknown, .neutral, .locked: nil
        }
    }
}

struct Tag: View {
    @Environment(\.theme) private var t
    let style: TagStyle
    var text: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if case .locked = style { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)) }
            Text(text ?? style.label)
        }
        .font(.system(size: 11.5, weight: .bold))
        .padding(.horizontal, 9).frame(height: 24)
        .foregroundStyle(style.colors?.1 ?? t.ink2)
        .background { if let c = style.colors { Capsule().fill(c.0) } else if case .unknown = style { EmptyView() } else { Capsule().fill(t.soft) } }
        .overlay { if case .unknown = style { Capsule().strokeBorder(t.ink2, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])) } }
        .fixedSize()
    }
}

// MARK: - Glyph tile (§3.2)

struct GlyphTile: View {
    let symbol: String
    let hue: ModuleHue
    var size: CGFloat = 58
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Palette.gradient(hue), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
            .shadow(color: hue.deep.opacity(0.35), radius: 10, y: 8)
    }
}

// MARK: - Rows & section headers

struct SectionHeader: View {
    @Environment(\.theme) private var t
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Typo.display(21, .bold, t)).tracking(-0.5).foregroundStyle(t.ink)
            Spacer()
            if let trailing {
                Button { action?() } label: {
                    HStack(spacing: 4) { Text(trailing); Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)) }
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(t.ink2)
                }.buttonStyle(.plain)
            }
        }.padding(.top, 24).padding(.bottom, 12)
    }
}

struct Row<Trailing: View>: View {
    @Environment(\.theme) private var t
    let icon: String
    let hue: ModuleHue
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(hue.deep)
                .frame(width: 42, height: 42).background(t.tile(hue), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.ink)
                if let subtitle { Text(subtitle).font(.system(size: 12.5)).foregroundStyle(t.ink2).lineLimit(2) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(minHeight: 62)
    }
}

// MARK: - Progress

struct Ring: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = Palette.mint
    var track: Color = .white.opacity(0.14)
    @State private var shown = 0.0
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle().trim(from: 0, to: shown).stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .onAppear { withAnimation(Motion.fill.delay(0.6)) { shown = progress } }
        .onChange(of: progress) { _, v in withAnimation(Motion.snappy) { shown = v } }
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color = Palette.ink
    var track: Color = Palette.ink.opacity(0.1)
    var stalled = false
    @State private var shown = 0.0
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint).frame(width: max(8, g.size.width * shown))
                    .overlay { if stalled { StripePattern().clipShape(Capsule()) } }
            }
        }
        .frame(height: 8)
        .onAppear { withAnimation(Motion.fill.delay(0.3)) { shown = progress } }
        .onChange(of: progress) { _, v in withAnimation(Motion.snappy) { shown = v } }
    }
}

/// 45° stripes, used for stalled / paused-by-iOS progress (§6.8).
struct StripePattern: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0))
                ctx.stroke(p, with: .color(.white.opacity(0.35)), lineWidth: 3); x += 8
            }
        }
    }
}

/// Live dot with a pulsing halo (§6.2).
struct LiveDot: View {
    var color: Color = Palette.mintDeep
    @State private var pulse = false
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .background(Circle().fill(color.opacity(0.3)).frame(width: 16, height: 16).scaleEffect(pulse ? 1.15 : 0.7).opacity(pulse ? 0.45 : 1))
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Two-tone headline (§4 signature)

struct TwoToneTitle: View {
    @Environment(\.theme) private var t
    let line1: String
    let line2: String
    var size: CGFloat = 32
    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(line1).foregroundStyle(t.ink)
            Text(line2).foregroundStyle(t.glass ? t.ink2 : t.ink3)
        }
        .font(Typo.display(size, .bold, t)).tracking(-size * 0.03)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Screen scaffold (custom large title, back circle, 128 pt bottom inset)

struct Screen<Content: View, Trailing: View>: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String? = nil
    var showsBack = false
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if showsBack { IconCircle(systemName: "chevron.left", filled: false) { dismiss() } }
                        Spacer()
                        trailing
                    }.frame(minHeight: 46).padding(.top, 6).rise(0)
                    Text(title).font(Typo.display(30, .bold, t)).tracking(-0.9).foregroundStyle(t.ink).padding(.top, 10).rise(0)
                    if let subtitle { Text(subtitle).font(.system(size: 14)).foregroundStyle(t.ink2).padding(.top, 4).rise(1) }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 128)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension Screen where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, showsBack: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, showsBack: showsBack, trailing: { EmptyView() }, content: content)
    }
}
