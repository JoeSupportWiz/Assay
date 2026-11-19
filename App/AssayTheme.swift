// Assay design tokens: SwiftUI. Drop-in starter; values match the mockups.
import SwiftUI

enum AssayThemeID: String, CaseIterable, Identifiable { case auto, light, dark, millennium, pinstripe, wallpaper; var id: String { rawValue } }

struct AssayTheme {
    var bg: Color, card: Color, cardBorder: Color, ink: Color, ink2: Color, ink3: Color, soft: Color
    var primary: AnyShapeStyle, onPrimary: Color, hero: AnyShapeStyle, heroInk: Color
    var accent: AnyShapeStyle, accentInk: Color, tiles: [Color], tabBar: AnyShapeStyle, tabActive: AnyShapeStyle, tabActiveInk: Color
    var cardRadius: CGFloat, tileRadius: CGFloat, pillRadius: CGFloat
    var display: Font.Design = .default, glossy = false, glass = false
}

extension Color { init(hex: UInt32, a: Double = 1) { self.init(.sRGB, red: Double((hex>>16)&0xff)/255, green: Double((hex>>8)&0xff)/255, blue: Double(hex&0xff)/255, opacity: a) } }
private func S(_ c: Color) -> AnyShapeStyle { AnyShapeStyle(c) }
private func G(_ c: [Color], stops: [CGFloat]? = nil) -> AnyShapeStyle {
    if let s = stops { return AnyShapeStyle(LinearGradient(stops: zip(c, s).map { .init(color: $0, location: $1) }, startPoint: .top, endPoint: .bottom)) }
    return AnyShapeStyle(LinearGradient(colors: c, startPoint: .top, endPoint: .bottom))
}
/// iOS-4 style gloss: two gradients with a hard stop at 50 %.
private func gloss(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) -> AnyShapeStyle { G([Color(hex:a),Color(hex:b),Color(hex:c),Color(hex:d)], stops: [0, 0.5, 0.5, 1]) }

extension AssayTheme {
    static let light = AssayTheme(bg: .init(hex: 0xF3F2EE), card: .white, cardBorder: .clear, ink: .init(hex: 0x111113), ink2: .init(hex: 0x6B6B72), ink3: .init(hex: 0xA3A3AA), soft: .init(hex: 0xF3F2EE),
        primary: S(.init(hex: 0x111113)), onPrimary: .white, hero: S(.init(hex: 0x111113)), heroInk: .white,
        accent: S(.init(hex: 0xFFE58A)), accentInk: .init(hex: 0x111113), tiles: [.init(hex: 0xDCD1FF), .init(hex: 0xC4E6FF), .init(hex: 0xBDF3D7)],
        tabBar: S(.init(hex: 0x111113)), tabActive: S(.white), tabActiveInk: .init(hex: 0x111113), cardRadius: 28, tileRadius: 18, pillRadius: 999)
    static let dark = AssayTheme(bg: .init(hex: 0x0B0B0D), card: .init(hex: 0x17171A), cardBorder: .init(hex: 0x202024), ink: .init(hex: 0xF5F4F0), ink2: .init(hex: 0x9A9AA2), ink3: .init(hex: 0x5E5E66), soft: .init(hex: 0x222226),
        primary: S(.init(hex: 0xF5F4F0)), onPrimary: .init(hex: 0x111113), hero: S(.init(hex: 0x1D1D21)), heroInk: .init(hex: 0xF5F4F0),
        accent: S(.init(hex: 0xFFE58A)), accentInk: .init(hex: 0x111113), tiles: [.init(hex: 0x241D45), .init(hex: 0x10283D), .init(hex: 0x0F3123)],
        tabBar: S(.init(hex: 0x1C1C20)), tabActive: S(.init(hex: 0xF5F4F0)), tabActiveInk: .init(hex: 0x111113), cardRadius: 28, tileRadius: 18, pillRadius: 999)
    static let millennium = AssayTheme(bg: .init(hex: 0xECE9D8), card: .white, cardBorder: .init(hex: 0x7F9DB9), ink: .black, ink2: .init(hex: 0x4D4D4D), ink3: .init(hex: 0x808080), soft: .init(hex: 0xF1EFE2),
        primary: G([.init(hex: 0x3C9A2E), .init(hex: 0x5CC84A), .init(hex: 0x2A8422)]), onPrimary: .white,
        hero: G([.init(hex: 0x0A5BE8), .init(hex: 0x3A8CFF), .init(hex: 0x0B55DB), .init(hex: 0x0844C7)], stops: [0, 0.12, 0.55, 1]), heroInk: .white,
        accent: S(.init(hex: 0xFFF6C9)), accentInk: .black, tiles: [.init(hex: 0xD6E3FA), .init(hex: 0xFFF6C9), .init(hex: 0xE0F2D6)],
        tabBar: G([.init(hex: 0x3C81F3), .init(hex: 0x245EDB), .init(hex: 0x2A68E8), .init(hex: 0x1C4FC4)], stops: [0, 0.08, 0.45, 1]),
        tabActive: G([.init(hex: 0x4BB140), .init(hex: 0x36A02C), .init(hex: 0x2A8422)]), tabActiveInk: .white, cardRadius: 8, tileRadius: 4, pillRadius: 4)
    static let pinstripe = AssayTheme(bg: .init(hex: 0xC5CCD4), card: .white, cardBorder: .init(hex: 0xA7ABB2), ink: .black, ink2: .init(hex: 0x4C566C), ink3: .init(hex: 0x7A8394), soft: .init(hex: 0xE3E6EA),
        primary: gloss(0x8FB2EE, 0x4C82E0, 0x2D66D6, 0x2F6BDA), onPrimary: .white, hero: gloss(0x5A5A5E, 0x2E2E31, 0x141416, 0x0A0A0B), heroInk: .white,
        accent: gloss(0xFFF3A8, 0xFBE25C, 0xF5D338, 0xF2C925), accentInk: .init(hex: 0x3A2A00), tiles: [.white, .white, .white],
        tabBar: gloss(0x4A4A4D, 0x262628, 0x0E0E0F, 0x050505), tabActive: S(.white.opacity(0.14)), tabActiveInk: .white, cardRadius: 11, tileRadius: 13, pillRadius: 9, glossy: true)
}

/// Pinstripe background (iOS-4 homage): 5 pt + 2 pt vertical stripes.
struct PinstripeBackground: View {
    var body: some View { Canvas { ctx, size in
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.init(hex: 0xC5CCD4)))
        var x: CGFloat = 5; while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(.init(hex: 0xCBD2D8))); x += 7 }
    }.ignoresSafeArea() }
}

enum AssayMotion {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let bouncy = Animation.spring(response: 0.55, dampingFraction: 0.62)
    static let fill   = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 1.4)
    static func stagger(_ i: Int) -> Animation { spring.delay(0.15 + Double(i) * 0.09) }
}

/// Entrance: rise 26 pt + scale 0.98 → identity, staggered. Honours Reduce Motion.
struct Rise: ViewModifier {
    let index: Int; @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 26).scaleEffect(shown || reduce ? 1 : 0.98)
            .onAppear { withAnimation(reduce ? .easeOut(duration: 0.2) : AssayMotion.stagger(index)) { shown = true } }
    }
}
extension View { func rise(_ i: Int) -> some View { modifier(Rise(index: i)) } }

/// Press feedback for every tappable surface.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(configuration.isPressed ? .easeOut(duration: 0.12) : AssayMotion.snappy, value: configuration.isPressed)
    }
}

enum SafetyTier { case reversible, caution, experimental
    var colors: (bg: Color, ink: Color) { switch self {
        case .reversible: (.init(hex: 0xBDF3D7), .init(hex: 0x0D5C37))
        case .caution: (.init(hex: 0xFFE58A), .init(hex: 0x5A4300))
        case .experimental: (.init(hex: 0xFFD6BF), .init(hex: 0x8A3300)) } }
}
enum Evidence { case observed, inferred, unknown }
