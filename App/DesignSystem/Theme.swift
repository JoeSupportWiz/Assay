import SwiftUI

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Palette (design spec §3)

enum Palette {
    static let lilac = Color(hex: 0xDCD1FF), lilacDeep = Color(hex: 0x7C5CFF)
    static let sky = Color(hex: 0xC4E6FF), skyDeep = Color(hex: 0x2E9BFF)
    static let mint = Color(hex: 0xBDF3D7), mintDeep = Color(hex: 0x38C98A)
    static let butter = Color(hex: 0xFFE58A), butterDeep = Color(hex: 0xE9C24A)
    static let peach = Color(hex: 0xFFD6BF), peachDeep = Color(hex: 0xFF7A3D)
    static let ink = Color(hex: 0x111113)
    static let paper = Color(hex: 0xF5F4F0)
    static let destructive = Color(hex: 0xFF453A)

    /// 150° glyph-tile gradients (§3.2).
    static func gradient(_ module: ModuleHue) -> LinearGradient {
        let c: [Color]
        switch module {
        case .lilac: c = [Color(hex: 0xA893FF), Color(hex: 0x6A47F5)]
        case .sky: c = [Color(hex: 0x7CC4FF), Color(hex: 0x1F84F0)]
        case .mint: c = [Color(hex: 0x6EE7B0), Color(hex: 0x1FAE6E)]
        case .butter: c = [Color(hex: 0xFFE58A), Color(hex: 0xE9A93A)]
        case .peach: c = [Color(hex: 0xFFB07A), Color(hex: 0xFF7A3D)]
        }
        return LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum ModuleHue: CaseIterable { case lilac, sky, mint, butter, peach
    var tile: Color { switch self { case .lilac: Palette.lilac; case .sky: Palette.sky; case .mint: Palette.mint; case .butter: Palette.butter; case .peach: Palette.peach } }
    var darkTile: Color { switch self { case .lilac: Color(hex: 0x241D45); case .sky: Color(hex: 0x10283D); case .mint: Color(hex: 0x0F3123); case .butter: Palette.butter; case .peach: Color(hex: 0x3A2216) } }
    var deep: Color { switch self { case .lilac: Palette.lilacDeep; case .sky: Palette.skyDeep; case .mint: Palette.mintDeep; case .butter: Palette.butterDeep; case .peach: Palette.peachDeep } }
}

// MARK: - Themes (§3.4)

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case auto, light, dark, millennium, pinstripe, wallpaper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"; case .light: "Light"; case .dark: "Dark"
        case .millennium: "Millennium"; case .pinstripe: "Pinstripe"; case .wallpaper: "Wallpaper match"
        }
    }
    var subtitle: String {
        switch self {
        case .auto: "Follows iOS"; case .light: "Paper and pastels"; case .dark: "Near-black, raised cards"
        case .millennium: "A friendly homage to 2001"; case .pinstripe: "Glossy, skeuomorphic homage"
        case .wallpaper: "Glass over your wallpaper"
        }
    }
}

struct Theme {
    var id: ThemeID
    var bg: Color, card: Color, cardBorder: Color?
    var ink: Color, ink2: Color, ink3: Color, soft: Color
    var primary: AnyShapeStyle, onPrimary: Color
    var hero: AnyShapeStyle, heroInk: Color
    var accent: AnyShapeStyle, accentInk: Color
    var tabBar: AnyShapeStyle, tabActive: AnyShapeStyle, tabActiveInk: Color, tabInk: Color
    var cardRadius: CGFloat, tileRadius: CGFloat, pillRadius: CGFloat
    var titleFont: Font.Design = .default
    var fontName: String? = nil
    var listCorner: CGFloat = 12
    var glossy = false
    var glass = false
    var isDark = false
    var wallpaperColors: [Color] = []

    func tile(_ hue: ModuleHue) -> Color {
        if id == .millennium { return [Color(hex: 0xD6E3FA), Color(hex: 0xFFF6C9), Color(hex: 0xE0F2D6), Color(hex: 0xFFF6C9), Color(hex: 0xFBE3D3)][ModuleHue.allCases.firstIndex(of: hue)!] }
        if id == .pinstripe { return .white }
        if glass { return Color.white.opacity(0.16) }
        return isDark ? hue.darkTile : hue.tile
    }
}

private func S(_ c: Color) -> AnyShapeStyle { AnyShapeStyle(c) }
private func G(_ stops: [(UInt32, CGFloat)]) -> AnyShapeStyle {
    AnyShapeStyle(LinearGradient(stops: stops.map { .init(color: Color(hex: $0.0), location: $0.1) }, startPoint: .top, endPoint: .bottom))
}
/// iOS-4 hard-stop gloss: two gradients meeting at 50 %.
private func gloss(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) -> AnyShapeStyle { G([(a, 0), (b, 0.5), (c, 0.5), (d, 1)]) }

extension Theme {
    static let light = Theme(id: .light, bg: Color(hex: 0xF3F2EE), card: .white, cardBorder: nil,
        ink: Palette.ink, ink2: Color(hex: 0x6B6B72), ink3: Color(hex: 0xA3A3AA), soft: Color(hex: 0xECEBE6),
        primary: S(Palette.ink), onPrimary: .white, hero: S(Palette.ink), heroInk: .white,
        accent: S(Palette.butter), accentInk: Palette.ink,
        tabBar: S(Palette.ink), tabActive: S(.white), tabActiveInk: Palette.ink, tabInk: Color.white.opacity(0.62),
        cardRadius: 28, tileRadius: 18, pillRadius: 999)

    static let dark = Theme(id: .dark, bg: Color(hex: 0x0B0B0D), card: Color(hex: 0x17171A), cardBorder: Color(hex: 0x202024),
        ink: Palette.paper, ink2: Color(hex: 0x9A9AA2), ink3: Color(hex: 0x5E5E66), soft: Color(hex: 0x222226),
        primary: S(Palette.paper), onPrimary: Palette.ink, hero: S(Color(hex: 0x1D1D21)), heroInk: Palette.paper,
        accent: S(Palette.butter), accentInk: Palette.ink,
        tabBar: S(Color(hex: 0x1C1C20)), tabActive: S(Palette.paper), tabActiveInk: Palette.ink, tabInk: Color.white.opacity(0.55),
        cardRadius: 28, tileRadius: 18, pillRadius: 999, isDark: true)

    static let millennium = Theme(id: .millennium, bg: Color(hex: 0xECE9D8), card: .white, cardBorder: Color(hex: 0x7F9DB9),
        ink: .black, ink2: Color(hex: 0x4D4D4D), ink3: Color(hex: 0x808080), soft: Color(hex: 0xF1EFE2),
        primary: G([(0x3C9A2E, 0), (0x5CC84A, 0.45), (0x2A8422, 1)]), onPrimary: .white,
        hero: G([(0x0A5BE8, 0), (0x3A8CFF, 0.12), (0x0B55DB, 0.55), (0x0844C7, 1)]), heroInk: .white,
        accent: S(Color(hex: 0xFFF6C9)), accentInk: .black,
        tabBar: G([(0x3C81F3, 0), (0x245EDB, 0.08), (0x2A68E8, 0.45), (0x1C4FC4, 1)]),
        tabActive: G([(0x4BB140, 0), (0x36A02C, 0.5), (0x2A8422, 1)]), tabActiveInk: .white, tabInk: .white.opacity(0.85),
        cardRadius: 8, tileRadius: 4, pillRadius: 4, fontName: "Tahoma", listCorner: 4)

    static let pinstripe = Theme(id: .pinstripe, bg: Color(hex: 0xC5CCD4), card: .white, cardBorder: Color(hex: 0xA7ABB2),
        ink: .black, ink2: Color(hex: 0x4C566C), ink3: Color(hex: 0x7A8394), soft: Color(hex: 0xE3E6EA),
        primary: gloss(0x8FB2EE, 0x4C82E0, 0x2D66D6, 0x2F6BDA), onPrimary: .white,
        hero: gloss(0x5A5A5E, 0x2E2E31, 0x141416, 0x0A0A0B), heroInk: .white,
        accent: gloss(0xFFF3A8, 0xFBE25C, 0xF5D338, 0xF2C925), accentInk: Color(hex: 0x3A2A00),
        tabBar: gloss(0x4A4A4D, 0x262628, 0x0E0E0F, 0x050505), tabActive: S(.white.opacity(0.14)), tabActiveInk: .white, tabInk: .white.opacity(0.7),
        cardRadius: 11, tileRadius: 13, pillRadius: 9, glossy: true, fontName: "HelveticaNeue", listCorner: 10)

    /// Glass over a wallpaper palette (lightest → primary, darkest → onPrimary).
    static func wallpaper(_ palette: WallpaperPalette) -> Theme {
        Theme(id: .wallpaper, bg: palette.darkest, card: .white.opacity(0.13), cardBorder: .white.opacity(0.2),
              ink: .white, ink2: .white.opacity(0.78), ink3: .white.opacity(0.5), soft: .white.opacity(0.12),
              primary: S(palette.lightest), onPrimary: palette.darkest, hero: S(Color.black.opacity(0.32)), heroInk: .white,
              accent: S(palette.lightest.opacity(0.9)), accentInk: palette.darkest,
              tabBar: S(Color.black.opacity(0.38)), tabActive: S(palette.lightest), tabActiveInk: palette.darkest, tabInk: .white.opacity(0.75),
              cardRadius: 28, tileRadius: 18, pillRadius: 999, glass: true, isDark: true, wallpaperColors: palette.colors)
    }
}

/// Five swatches sorted light → dark. Default: "Dusk".
struct WallpaperPalette: Codable, Equatable {
    var hex: [UInt32]
    static let dusk = WallpaperPalette(hex: [0xFFE58A, 0xFF9E6B, 0xC9783F, 0x7A58FF, 0x2A1660])
    var colors: [Color] { hex.map { Color(hex: $0) } }
    var lightest: Color { Color(hex: hex.first ?? 0xFFFFFF) }
    var darkest: Color { Color(hex: hex.last ?? 0x000000) }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.light }
extension EnvironmentValues {
    var theme: Theme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}
