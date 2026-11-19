import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var step = 0
    @State private var choice: EngineMode = .iphone
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
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
            Spacer().frame(height: 24)
            Image("fold-symbol").renderingMode(.template).resizable().scaledToFit().frame(width: 94, height: 94).foregroundStyle(t.ink).accessibilityHidden(true)
            Text("Assay").font(.largeTitle.weight(.bold)).tracking(-1).foregroundStyle(t.ink)
            Text("Check your iPhone, edit wallpapers and inspect the apps you sign.")
                .font(.body).foregroundStyle(t.ink2)
            TextField("Your name (optional)", text: $name)
                .padding(14).background(t.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
        }
    }

    private var engine: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 40)
            Text("How should Assay reach your iPhone?").font(.title.bold()).foregroundStyle(t.ink)
            Text("You can change this later in More › Engine.").foregroundStyle(t.ink2)
            option(.mac, "Mac companion", "Hand off a standard USB backup to your Mac and import its result.")
            option(.iphone, "iPhone only", "Check the clock, inspect logs, or save a corrected copy of a display preset.")
        }
    }

    private func option(_ m: EngineMode, _ title: String, _ detail: String) -> some View {
        Button { choice = m; Haptics.selection() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: choice == m ? "largecircle.fill.circle" : "circle").foregroundStyle(choice == m ? t.accentColor : t.ink3).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.ink)
                    Text(detail).font(.subheadline).foregroundStyle(t.ink2).multilineTextAlignment(.leading)
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
