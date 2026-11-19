import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var step = 0
    @State private var choice: EngineMode = .iphone
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                default: engine
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button(step == 0 ? "Continue" : "Get started") { advance() }
                    .buttonStyle(PrimaryButtonStyle())
                if step == 1 {
                    Button("Explore with a demo device") { finish(.demo) }.buttonStyle(.plain).foregroundStyle(t.ink2).font(.system(size: 15))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(ThemedBackground())
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 60)
            FoldMark().fill(t.ink).frame(width: 56, height: 80)
            Text("Assay").font(.system(size: 40, weight: .heavy)).tracking(-1.5).foregroundStyle(t.ink)
            Text("Customise, sign and inspect your iPhone. Every change is previewed first, checked afterwards, and can be undone.")
                .font(.system(size: 17)).foregroundStyle(t.ink2)
            TextField("Your name (optional)", text: $name)
                .padding(14).background(t.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
        }
    }

    private var engine: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 40)
            Text("How should Assay reach your iPhone?").font(.system(size: 28, weight: .bold)).foregroundStyle(t.ink)
            Text("You can change this later in More › Engine.").foregroundStyle(t.ink2)
            option(.mac, "Mac companion", "Fastest. USB, no tunnel stalls, keeps going while the phone is locked. Data passes through your Mac. Needs Assay for Mac.")
            option(.iphone, "iPhone only", "Most private. Everything stays on this phone. Slower, and iOS can pause it when the screen is off.")
        }
    }

    private func option(_ m: EngineMode, _ title: String, _ detail: String) -> some View {
        Button { choice = m; Haptics.selection() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: choice == m ? "largecircle.fill.circle" : "circle").foregroundStyle(choice == m ? t.accentColor : t.ink3).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.ink)
                    Text(detail).font(.system(size: 14)).foregroundStyle(t.ink2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14).background(t.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(choice == m ? t.accentColor : .clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }

    private func advance() {
        if step == 0 { model.userName = name.trimmingCharacters(in: .whitespaces); step = 1 } else { finish(choice) }
    }

    private func finish(_ mode: EngineMode) {
        model.engineMode = mode
        model.hasOnboarded = true
        Task { await model.refresh() }
    }
}
