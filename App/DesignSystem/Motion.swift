import SwiftUI
import UIKit

// MARK: - Motion (§9)

enum Motion {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let bouncy = Animation.spring(response: 0.55, dampingFraction: 0.62)
    static let fill = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 1.4)
    static let sweep = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)
    static func stagger(_ i: Int) -> Animation { spring.delay(0.15 + Double(min(i, 10)) * 0.09) }
}

/// Entrance: rise 26 pt + scale 0.98 → identity, staggered. Honours Reduce Motion.
struct Rise: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 26)
            .scaleEffect(shown || reduce ? 1 : 0.98)
            .onAppear { withAnimation(reduce ? .easeOut(duration: 0.2) : Motion.stagger(index)) { shown = true } }
    }
}

/// Ambient float (±6 pt over 6 s), phase-shifted per index.
struct FloatMotion: ViewModifier {
    let index: Int
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content.offset(y: reduce ? 0 : (up ? -6 : 6))
            .onAppear {
                guard !reduce else { return }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(Double(index) * 0.7)) { up = true }
            }
    }
}

/// Diagonal white band sweeping across live cards (§6.3).
struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content.overlay {
            if !reduce {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.45)
                        .rotationEffect(.degrees(10))
                        .offset(x: x * g.size.width * 1.6)
                        .blendMode(.plusLighter)
                        .onAppear {
                            withAnimation(.linear(duration: 1.3).delay(1.2).repeatForever(autoreverses: false).delay(1.3)) { x = 1 }
                        }
                }.allowsHitTesting(false).clipped()
            }
        }
    }
}

extension View {
    func rise(_ i: Int) -> some View { modifier(Rise(index: i)) }
    func floating(_ i: Int) -> some View { modifier(FloatMotion(index: i)) }
    func shimmer() -> some View { modifier(Shimmer()) }
}

/// Scale 0.96 + darken on press, snappy release (§6.1).
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(configuration.isPressed ? .easeOut(duration: 0.12) : Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Haptics (§9.5)

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func tap(_ s: UIImpactFeedbackGenerator.FeedbackStyle = .light) { UIImpactFeedbackGenerator(style: s).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - Typography (§4)

enum Typo {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold, _ theme: Theme) -> Font {
        switch theme.id {
        case .millennium: .custom("Tahoma", size: size * 0.86).weight(weight)
        case .pinstripe: .custom("Helvetica Neue", size: size * 0.86).weight(weight)
        default: .system(size: size, weight: weight, design: .default)
        }
    }
    static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat = 12, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}
