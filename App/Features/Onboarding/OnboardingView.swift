import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var step = 0
    @State private var name = ""
    @State private var choice: EngineMode? = nil

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule().fill(i <= step ? t.ink : t.ink.opacity(0.15)).frame(width: i == step ? 26 : 8, height: 8)
                    }
                    Spacer()
                    if step > 0 {
                        Button("Back") { withAnimation(Motion.spring) { step -= 1 } }.font(.system(size: 15, weight: .medium)).foregroundStyle(t.ink2)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8)
                .animation(Motion.snappy, value: step)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: engine
                    default: promises
                    }
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
    }

    // MARK: Step 1 — welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            LaunchMark().frame(width: 92, height: 130).rise(0)
            TwoToneTitle(line1: "Your iPhone,", line2: "shown its work.", size: 40).padding(.top, 28).rise(1)
            Text("Customise, sign and inspect your iPhone. Every change is previewed, explained, verified where iOS allows, and reversible.")
                .font(.system(size: 16)).foregroundStyle(t.ink2).padding(.top, 14).rise(2)
            TextField("What should we call you?", text: $name)
                .font(.system(size: 16, weight: .medium)).textContentType(.givenName).submitLabel(.next)
                .padding(.horizontal, 18).frame(height: 54).card(radius: 27).padding(.top, 28).rise(3)
            Spacer()
            PillButton(title: "Get started", icon: "arrow.right") {
                model.userName = name
                withAnimation(Motion.spring) { step = 1 }
            }.rise(4)
        }
        .padding(24)
    }

    // MARK: Step 2 — engine choice

    private var engine: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TwoToneTitle(line1: "How should Assay", line2: "reach your iPhone?", size: 32).padding(.top, 24).rise(0)
                    Text("You can change this any time in More › Engine.").font(.system(size: 14)).foregroundStyle(t.ink2).padding(.top, 8).rise(1)

                    EngineOption(mode: .mac, selected: choice == .mac,
                                 badge: "Fastest",
                                 points: [("bolt.fill", "Backups over USB — no tunnel stalls"),
                                          ("lock.open.display", "Keeps going while your iPhone is locked"),
                                          ("laptopcomputer", "Needs a Mac running Assay for Mac"),
                                          ("arrow.left.arrow.right", "Your data passes through your own Mac")]) { choice = .mac }
                        .padding(.top, 22).rise(2)

                    EngineOption(mode: .iphone, selected: choice == .iphone,
                                 badge: "Most private",
                                 points: [("iphone", "Everything stays on this phone"),
                                          ("network.badge.shield.half.filled", "Uses Assay's own loopback — no other VPN app"),
                                          ("tortoise.fill", "Slower; iOS pauses work when the app leaves the screen"),
                                          ("person.badge.key", "Needs a paid developer team for the loopback")]) { choice = .iphone }
                        .padding(.top, 12).rise(3)

                    Button { choice = .demo } label: {
                        HStack {
                            Image(systemName: choice == .demo ? "checkmark.circle.fill" : "circle").font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Just look around").font(.system(size: 15, weight: .semibold))
                                Text("Demo device — nothing touches your iPhone").font(.system(size: 12.5)).foregroundStyle(t.ink2)
                            }
                            Spacer()
                        }.foregroundStyle(t.ink).padding(16).card(radius: 22)
                    }.buttonStyle(PressStyle()).padding(.top, 12).rise(4)
                }
            }
            PillButton(title: choice == nil ? "Choose an option" : "Continue", icon: "arrow.right") {
                guard let choice else { Haptics.error(); return }
                model.engineMode = choice
                withAnimation(Motion.spring) { step = 2 }
            }
            .opacity(choice == nil ? 0.4 : 1)
            .padding(.top, 12)
        }
        .padding(24)
        .animation(Motion.snappy, value: choice)
    }

    // MARK: Step 3 — promises

    private var promises: some View {
        VStack(alignment: .leading, spacing: 0) {
            TwoToneTitle(line1: "Four promises,", line2: "kept on every change.", size: 32).padding(.top, 24).rise(0)
            VStack(spacing: 12) {
                Promise(symbol: "eye", hue: .sky, title: "Shows its work", text: "Every finding is labelled Observed, Inferred or Unknown.").rise(1)
                Promise(symbol: "doc.text.magnifyingglass", hue: .lilac, title: "Preview first", text: "You see the exact diff and risk before anything changes.").rise(2)
                Promise(symbol: "arrow.uturn.backward", hue: .mint, title: "Reversible", text: "Snapshots and receipts. If it can't be undone, we say so first.").rise(3)
                Promise(symbol: "hand.raised", hue: .peach, title: "You approve", text: "AI and automations propose. Nothing is applied without you.").rise(4)
            }.padding(.top, 24)
            Spacer()
            PillButton(title: "Open Assay", icon: "arrow.right") {
                Haptics.success()
                model.hasOnboarded = true
            }.rise(5)
        }
        .padding(24)
    }
}

private struct EngineOption: View {
    @Environment(\.theme) private var t
    let mode: EngineMode
    let selected: Bool
    let badge: String
    let points: [(String, String)]
    let action: () -> Void
    var body: some View {
        Button { Haptics.selection(); action() } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GlyphTile(symbol: mode.symbol, hue: mode == .mac ? .lilac : .mint, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.title).font(.system(size: 18, weight: .bold))
                        Tag(style: mode == .mac ? .live : .reversible, text: badge)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 24))
                        .foregroundStyle(selected ? Palette.mintDeep : t.ink3)
                }
                ForEach(points.indices, id: \.self) { i in
                    let p = points[i]
                    HStack(spacing: 10) {
                        Image(systemName: p.0).font(.system(size: 13, weight: .semibold)).frame(width: 20).foregroundStyle(t.ink2)
                        Text(p.1).font(.system(size: 14)).foregroundStyle(t.ink)
                    }
                }
            }
            .foregroundStyle(t.ink)
            .padding(18)
            .card(radius: 26)
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(t.ink, lineWidth: selected ? 2.5 : 0))
            .scaleEffect(selected ? 1.0 : 0.985)
        }.buttonStyle(PressStyle())
    }
}

private struct Promise: View {
    @Environment(\.theme) private var t
    let symbol: String, hue: ModuleHue, title: String, text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GlyphTile(symbol: symbol, hue: hue, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(t.ink)
                Text(text).font(.system(size: 14)).foregroundStyle(t.ink2)
            }
            Spacer(minLength: 0)
        }.padding(16).card(radius: 22)
    }
}

/// The Fold mark building itself (§1A launch animation): planes drop, rise and fold into place.
struct LaunchMark: View {
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var phase = 0
    var body: some View {
        FoldMark().fill(t.ink)
            .scaleEffect(y: phase >= 2 ? 1 : 0.6, anchor: .bottom)
            .offset(y: phase >= 1 ? 0 : -10)
            .opacity(phase >= 1 ? 1 : 0)
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.5).rotationEffect(.degrees(-20))
                        .offset(x: phase >= 3 ? g.size.width * 1.4 : -g.size.width)
                }.mask(FoldMark())
            }
            .onAppear {
                if reduce { phase = 3; return }
                withAnimation(Motion.spring.delay(0.25)) { phase = 1 }
                withAnimation(Motion.bouncy.delay(0.67)) { phase = 2 }
                withAnimation(.easeInOut(duration: 0.7).delay(1.05)) { phase = 3 }
            }
    }
}
