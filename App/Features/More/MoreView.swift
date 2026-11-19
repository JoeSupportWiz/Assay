import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                NavigationLink { AppearanceView() } label: { LabeledContent("Appearance") { Text(model.themeID.title) } }
                NavigationLink { EngineView() } label: { LabeledContent("Engine") { Text(model.engineMode?.title ?? "Not set") } }
                NavigationLink { AISettingsView() } label: { Label("AI providers", systemImage: "brain") }
                Toggle("Expert mode", isOn: $model.expertMode)
            } footer: { Text("Expert mode shows raw keys, bundle IDs and UUIDs inline.") }.rowCard()

            Section("Coming up") {
                ForEach(Self.upcoming, id: \.title) { u in
                    HStack { Label(u.title, systemImage: u.symbol).foregroundStyle(t.ink2); Spacer(); Tag(style: .neutral, text: u.phase) }
                }
            }.rowCard()

            Section {
                LabeledContent("Version") { Text("0.1.0 (1)") }
                LabeledContent("Build") { Text("Phase 1 · safety core") }
            } footer: { Text("Assay is a working name · not affiliated with Apple.") }.rowCard()
        }
        .themedList()
        .navigationTitle("More")
    }

    private struct Upcoming { let title: String; let symbol: String; let phase: String }
    private static let upcoming: [Upcoming] = [
        .init(title: "Permissions and privacy", symbol: "hand.raised", phase: "Phase 8"),
        .init(title: "Updates", symbol: "arrow.down.circle", phase: "Phase 2"),
        .init(title: "Assay Pro", symbol: "star", phase: "Phase 9"),
    ]
}

struct AppearanceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                ForEach(ThemeID.allCases) { id in
                    Button { model.themeID = id; Haptics.selection() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(id.title).foregroundStyle(t.ink)
                                Text(id.subtitle).font(.system(size: 13)).foregroundStyle(t.ink2)
                            }
                            Spacer()
                            if model.themeID == id { Image(systemName: "checkmark").foregroundStyle(t.accentColor) }
                        }
                    }
                }
            } footer: { Text("Millennium and Pinstripe are original homages. Wallpaper match uses a colour palette; iOS doesn't share your wallpaper with apps.") }.rowCard()
        }
        .themedList()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EngineView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var availability: EngineAvailability?

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                ForEach(EngineMode.allCases) { m in
                    Button { model.engineMode = m; Haptics.selection(); Task { availability = await model.engine.availability() } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.symbol).frame(width: 28).foregroundStyle(t.ink2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).foregroundStyle(t.ink)
                                Text(blurb(m)).font(.system(size: 13)).foregroundStyle(t.ink2)
                            }
                            Spacer()
                            if model.engineMode == m { Image(systemName: "checkmark").foregroundStyle(t.accentColor) }
                        }
                    }
                }
            } footer: { Text("Use iPhone only for real device checks. Choose Demo to practise reviewing and undoing changes without changing your phone.") }.rowCard()

            Section("Status") {
                switch availability {
                case .ready: Label("Ready", systemImage: "checkmark.circle").foregroundStyle(t.ink)
                case .needsSetup(let s): Label(s, systemImage: "exclamationmark.circle").foregroundStyle(t.ink)
                case .unavailable(let s): Label(s, systemImage: "xmark.circle").foregroundStyle(t.ink)
                case nil: ProgressView()
                }
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Engine")
        .navigationBarTitleDisplayMode(.inline)
        .task { availability = await model.engine.availability() }
    }

    private func blurb(_ m: EngineMode) -> String {
        switch m {
        case .mac: "Planned · not available in this build"
        case .iphone: "Read-only · checks this iPhone"
        case .demo: "Sample device to explore the app"
        }
    }
}
