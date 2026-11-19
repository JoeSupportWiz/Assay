import SwiftUI
import UIKit

// MARK: - Fold mark (drawn from brand/svg/symbol.svg; vector, so always sharp)

struct FoldMark: Shape {
    func path(in r: CGRect) -> Path {
        let scale = min(r.width / 50, r.height / 71.7)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.midX + (x - 42) * scale, y: r.midY + (y - 41.35) * scale) }
        var path = Path()
        path.move(to: p(17, 25.5)); path.addQuadCurve(to: p(19.4, 21.4), control: p(17, 22.8))
        path.addLine(to: p(42.5, 8.1)); path.addQuadCurve(to: p(47, 10.8), control: p(47, 5.5))
        path.addLine(to: p(47, 24.2)); path.addLine(to: p(28.2, 35.1)); path.addQuadCurve(to: p(25.5, 39.7), control: p(25.5, 36.7))
        path.addLine(to: p(25.5, 51.8)); path.addQuadCurve(to: p(23.1, 56), control: p(25.5, 54.6))
        path.addLine(to: p(17, 59.5)); path.closeSubpath()
        path.move(to: p(34, 34.8)); path.addQuadCurve(to: p(36.4, 30.7), control: p(34, 32.1))
        path.addLine(to: p(62.6, 15.6)); path.addQuadCurve(to: p(67, 18.3), control: p(67, 13.1))
        path.addLine(to: p(67, 44.4)); path.addQuadCurve(to: p(64.6, 48.5), control: p(67, 47.1))
        path.addLine(to: p(38.4, 63.6)); path.addQuadCurve(to: p(34, 60.9), control: p(34, 66.1)); path.closeSubpath()
        path.move(to: p(34, 57.4)); path.addLine(to: p(54.8, 45.4)); path.addQuadCurve(to: p(59.8, 45.7), control: p(57.4, 43.9))
        path.addLine(to: p(67, 51)); path.addLine(to: p(67, 60.2)); path.addLine(to: p(41.8, 74.7))
        path.addQuadCurve(to: p(37.4, 72), control: p(37.4, 77.2)); path.addLine(to: p(37.4, 61.8))
        path.addQuadCurve(to: p(34, 57.4), control: p(37.4, 59.2)); path.closeSubpath()
        return path
    }
}

struct Wordmark: View {
    @Environment(\.theme) private var t
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: size * 0.34) {
            FoldMark().fill(t.ink).frame(width: size * 0.98, height: size * 1.4)
            Text("Assay").font(.system(size: size, weight: .heavy)).tracking(-size * 0.05).foregroundStyle(t.ink)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Assay")
    }
}

// MARK: - Motion and haptics (kept deliberately small)

enum Motion {
    static let spring = Animation.smooth(duration: 0.28)
    static let bouncy = Animation.smooth(duration: 0.28)
    static let snappy = Animation.snappy(duration: 0.2)
}

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - Tags (evidence and risk; always text + colour, never colour alone)

enum TagStyle: Equatable {
    case reversible, caution, experimental, observed, inferred(Int?), unknown, neutral
}

struct Tag: View {
    @Environment(\.theme) private var t
    let style: TagStyle
    var text: String? = nil

    private var label: String {
        if let text { return text }
        switch style {
        case .reversible: return "Reversible"
        case .caution: return "Caution"
        case .experimental: return "Experimental"
        case .observed: return "Observed"
        case .inferred(let p): return p.map { "Inferred · \($0)%" } ?? "Inferred"
        case .unknown: return "Unknown"
        case .neutral: return ""
        }
    }

    private var colours: (bg: Color, fg: Color) {
        let d = t.isDark
        switch style {
        case .reversible: return (Palette.mintDeep.opacity(d ? 0.22 : 0.20), d ? Color(hex: 0x7BE8B5) : Color(hex: 0x0D5C37))
        case .caution: return (Palette.butterDeep.opacity(d ? 0.24 : 0.28), d ? Color(hex: 0xFFD966) : Color(hex: 0x5A4300))
        case .experimental: return (Palette.peachDeep.opacity(d ? 0.24 : 0.20), d ? Color(hex: 0xFFA47A) : Color(hex: 0x8A3300))
        case .observed: return (Palette.skyDeep.opacity(d ? 0.24 : 0.16), d ? Color(hex: 0x8CCBFF) : Color(hex: 0x0B4A8A))
        case .inferred: return (Palette.lilacDeep.opacity(d ? 0.28 : 0.16), d ? Color(hex: 0xBBA8FF) : Color(hex: 0x4B33A8))
        case .unknown, .neutral: return (t.ink.opacity(0.08), t.ink2)
        }
    }

    var body: some View {
        if !label.isEmpty {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colours.fg)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(colours.bg, in: Capsule())
                .overlay { if style == .unknown { Capsule().strokeBorder(t.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) } }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Small pieces

/// Flat tinted tile for a module or setting. No gradient, no shadow.
struct IconTile: View {
    @Environment(\.theme) private var t
    let symbol: String
    var hue: ModuleHue = .lilac
    var size: CGFloat = 30
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(hue.deep)
            .frame(width: size, height: size)
            .background(hue.deep.opacity(t.isDark ? 0.22 : 0.15), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ThemedBackground: View {
    @Environment(\.theme) private var t
    var body: some View {
        if t.id == .wallpaper, t.wallpaperColors.count == 5 {
            LinearGradient(colors: [t.wallpaperColors[1], t.wallpaperColors[4]], startPoint: .top, endPoint: .bottom).overlay(Color.black.opacity(0.58)).ignoresSafeArea()
        } else if t.id == .pinstripe {
            Image(uiImage: PinstripeTile.image).resizable(resizingMode: .tile).ignoresSafeArea()
        } else {
            t.bg.ignoresSafeArea()
        }
    }
}

/// 7 pt tile (5 pt base + 2 pt stripe), rendered once at device scale and tiled. Cheap and sharp.
enum PinstripeTile {
    static let image: UIImage = {
        let size = CGSize(width: 7, height: 7)
        return UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = UIScreen.main.scale; f.opaque = true; return f }()).image { ctx in
            UIColor(red: 0xC5/255, green: 0xCC/255, blue: 0xD4/255, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0xCB/255, green: 0xD2/255, blue: 0xD8/255, alpha: 1).setFill(); ctx.fill(CGRect(x: 5, y: 0, width: 2, height: 7))
        }
    }()
}

extension View {
    /// Native grouped list on the theme's background and card colour.
    func themedList() -> some View { modifier(ThemedListStyle()) }
    /// Applies the theme's native bar styling (tab bar and navigation bar).
    func themedBars() -> some View { modifier(ThemedBars()) }
    func rowCard() -> some View { modifier(RowCard()) }
}

private struct ThemedListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(ThemedBackground())
    }
}

private struct RowCard: ViewModifier {
    @Environment(\.theme) private var t
    func body(content: Content) -> some View {
        if t.glass {
            content.listRowBackground(Color.black.opacity(0.48))
        } else {
            content.listRowBackground(t.card)
        }
    }
}

private struct ThemedBars: ViewModifier {
    @Environment(\.theme) private var t
    func body(content: Content) -> some View {
        switch t.id {
        case .millennium:
            content
                .toolbarBackground(Color(hex: 0xE3EACE), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.light, for: .tabBar)
        case .pinstripe:
            content
                .toolbarBackground(Color(hex: 0xDCE2EC), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.light, for: .tabBar)
        case .wallpaper:
            content
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        default:
            content
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var t
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(t.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(t.primary, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var t
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(t.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(t.ink.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
    }
}

struct FactRow: View {
    @Environment(\.theme) private var t
    let fact: Fact
    var body: some View {
        HStack(spacing: 10) {
            Text(fact.label).foregroundStyle(t.ink)
            Spacer(minLength: 8)
            Text(fact.value).foregroundStyle(t.ink2).multilineTextAlignment(.trailing)
            switch fact.evidence {
            case .observed: Tag(style: .observed)
            case .inferred(let p): Tag(style: .inferred(p))
            case .unknown: Tag(style: .unknown)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FindingRow: View {
    @Environment(\.theme) private var t
    let finding: Finding
    private var evidenceTag: TagStyle {
        if let p = finding.confidence { return .inferred(p) }
        if finding.evidence.isEmpty || finding.evidence.contains(where: { $0.evidence == .unknown }) { return .unknown }
        if finding.evidence.contains(where: { if case .inferred = $0.evidence { return true }; return false }) { return .inferred(nil) }
        return .observed
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: finding.severity == .info ? "info.circle" : "exclamationmark.triangle", hue: finding.severity == .info ? .sky : .peach)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title).font(.headline).foregroundStyle(t.ink)
                Text(finding.reason).font(.subheadline).foregroundStyle(t.ink2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Tag(style: evidenceTag)

                }.padding(.top, 2)
            }
            Spacer(minLength: 0)
            if finding.fix != nil { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.ink3).padding(.top, 4) }
        }
        .contentShape(Rectangle())
    }
}

/// Simple banner at the top (§7.2) without shadows or springs.
struct ToastHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    var body: some View {
        VStack {
            if let toast = model.toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.symbol).foregroundStyle(toast.kind == .warning ? Palette.peachDeep : Palette.mintDeep)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(toast.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.ink)
                        if let s = toast.subtitle { Text(s).font(.system(size: 13)).foregroundStyle(t.ink2) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { model.toast = nil }
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(3.5))
                    if model.toast?.id == toast.id { model.toast = nil }
                }
            }
            Spacer()
        }
        .animation(Motion.spring, value: model.toast)
        .allowsHitTesting(model.toast != nil)
    }
}
