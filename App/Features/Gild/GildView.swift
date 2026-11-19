import SwiftUI

struct GildView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        @Bindable var ts = model.tweaks
        List {
            if ts.search.isEmpty && ts.category == nil {
                Section("Presets") {
                    NavigationLink(value: StudioRoute.presetFiles) { Label("Import or export a preset", systemImage: "doc.on.doc") }
                    ForEach(Preset.all) { p in
                        NavigationLink(value: StudioRoute.gild(.preset(p.id))) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title).font(.system(size: 16, weight: .medium)).foregroundStyle(t.ink)
                                    Text(p.detail).font(.system(size: 13)).foregroundStyle(t.ink2).lineLimit(2)
                                }
                                Spacer(); Tag(style: p.tier.tag)
                            }
                        }
                    }
                }.rowCard()
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", symbol: nil, selected: ts.category == nil) { ts.category = nil }
                        ForEach(Tweak.Category.allCases) { c in chip(c.rawValue, symbol: c.symbol, selected: ts.category == c) { ts.category = c } }
                    }
                }.listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
            }.listRowBackground(Color.clear)

            let list = ts.filtered(osVersion: model.snapshot?.osVersion ?? "0")
            Section {
                ForEach(list) { tw in
                    TweakRow(tweak: tw)
                }
                if list.isEmpty { Text("No tweaks match.").foregroundStyle(t.ink2) }
            } header: { Text("\(list.count) tweak\(list.count == 1 ? "" : "s") · checked for iOS \(model.snapshot?.osVersion ?? "—")") }
            footer: {
                if !model.engine.canRead { Text("This engine can't read your device yet, so current states are unknown. You can still stage changes and review them.") }
                else { Text("Switches stage a change. Nothing is applied until you review.") }
            }.rowCard()
        }
        .themedList()
        .searchable(text: $ts.search, prompt: "Search tweaks")
        .navigationTitle("Gild")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { ReviewBar() }
        .task { await model.tweaks.load(engine: model.engine) }
    }

    private func chip(_ title: String, symbol: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.selection(); action() } label: {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(selected ? t.onPrimary : t.ink)
            .padding(.horizontal, 12).frame(height: 34)
            .background(selected ? t.primary : AnyShapeStyle(t.card), in: Capsule())
        }.buttonStyle(.plain)
    }
}

enum GildRoute: Hashable { case tweak(String), preset(String) }

struct TweakRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let tweak: Tweak

    var body: some View {
        let ts = model.tweaks
        let avail = tweak.availability(osVersion: model.snapshot?.osVersion ?? "0")
        let staged = ts.staged[tweak.id] != nil
        HStack(spacing: 10) {
            NavigationLink(value: StudioRoute.gild(.tweak(tweak.id))) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tweak.title).font(.system(size: 16, weight: .medium)).foregroundStyle(avail.isSupported ? t.ink : t.ink3)
                    HStack(spacing: 6) {
                        Tag(style: tweak.tier.tag)
                        if let r = avail.reason { Tag(style: .unknown, text: r) }
                        else if staged { Tag(style: .neutral, text: "Staged") }
                        else if ts.isOn(tweak) { Tag(style: .neutral, text: "On") }
                    }
                }
            }
            Spacer(minLength: 4)
            if tweak.isToggle {
                Toggle("", isOn: Binding(get: { ts.effectiveOn(tweak) }, set: { ts.toggle(tweak, on: $0); Haptics.selection() }))
                    .labelsHidden().disabled(!avail.isSupported)
            }
        }
        .opacity(avail.isSupported ? 1 : 0.6)
    }
}

/// "3 changes staged" bar that opens the fix sheet with the combined diff.
struct ReviewBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    var body: some View {
        let ts = model.tweaks
        if ts.stagedCount > 0 {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(ts.stagedCount) change\(ts.stagedCount == 1 ? "" : "s") staged").font(.system(size: 16, weight: .semibold))
                    Text("Highest risk: \(ts.stagedTier.title)").font(.system(size: 12.5)).opacity(0.7)
                }
                Spacer()
                Button("Discard") { withAnimation(Motion.spring) { ts.discard() } }.font(.system(size: 15, weight: .medium)).opacity(0.8)
                Button { model.activePlan = ts.plan() } label: {
                    Text("Review").font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 38)
                        .background(t.onPrimary.opacity(0.18), in: Capsule())
                }
            }
            .foregroundStyle(t.onPrimary)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(t.primary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16).padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct TweakDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let id: String

    var body: some View {
        if let tw = TweakCatalog.tweak(id) {
            let ts = model.tweaks
            let avail = tw.availability(osVersion: model.snapshot?.osVersion ?? "0")
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tw.title).font(.system(size: 22, weight: .bold)).foregroundStyle(t.ink)
                        Text(tw.detail).foregroundStyle(t.ink2)
                        HStack { Tag(style: tw.tier.tag); if tw.respring { Tag(style: .neutral, text: "Restarts SpringBoard") } }
                    }
                }.rowCard()

                Section {
                    switch tw.kind {
                    case .toggle:
                        Toggle("On", isOn: Binding(get: { ts.effectiveOn(tw) }, set: { ts.toggle(tw, on: $0) })).disabled(!avail.isSupported)
                    case .number(let mn, let mx, let step, let unit):
                        let v = ts.effectiveValue(tw)
                        let n: Double = { if case .int(let i)? = v { return Double(i) }; if case .double(let d)? = v { return d }; return mn }()
                        Toggle("On", isOn: Binding(get: { ts.effectiveOn(tw) }, set: { ts.toggle(tw, on: $0) })).disabled(!avail.isSupported)
                        if ts.effectiveOn(tw) {
                            Stepper(value: Binding(get: { n }, set: { ts.stage(tw, value: .int(Int($0))) }), in: mn...mx, step: step) {
                                LabeledContent("Value") { Text("\(Int(n)) \(unit)").monospacedDigit() }
                            }
                        }
                    case .text(let ph):
                        let cur: String = { if case .string(let s)? = ts.effectiveValue(tw) { return s }; return "" }()
                        TextField(ph, text: Binding(get: { cur }, set: { ts.stage(tw, value: $0.isEmpty ? nil : .string($0)) }))
                    }
                } header: { Text("Setting") } footer: {
                    if let r = avail.reason { Text(r) } else { Text("This stages a change. You'll review it before anything is applied.") }
                }.rowCard()

                Section("Safety") {
                    LabeledContent("Tier") { Tag(style: tw.tier.tag) }
                    Text(tw.tier.explanation).font(.system(size: 14)).foregroundStyle(t.ink2)
                    LabeledContent("Verified by") { Text(tw.verification).multilineTextAlignment(.trailing).font(.system(size: 14)) }
                    LabeledContent("If it goes wrong") { Text(tw.recovery).multilineTextAlignment(.trailing).font(.system(size: 14)) }
                    LabeledContent("Works on") { Text(range(tw)).font(.system(size: 14)) }
                }.rowCard()

                if model.expertMode {
                    Section("Expert") {
                        LabeledContent("Domain") { Text(tw.target.domain).font(.system(size: 12.5, design: .monospaced)).multilineTextAlignment(.trailing) }
                        LabeledContent("Key") { Text(tw.target.key).font(.system(size: 12.5, design: .monospaced)).multilineTextAlignment(.trailing) }
                    }.rowCard()
                }

                if let sid = tw.symptomID, let s = Knowledge.symptoms.first(where: { $0.id == sid }) {
                    Section("Related problem") {
                        Button { model.selectedTab = .lab; model.labPath = [.diagnose, .symptom(sid)] } label: { Label(s.title, systemImage: "stethoscope") }
                    }.rowCard()
                }
            }
            .themedList()
            .navigationTitle("Tweak")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { ReviewBar() }
        }
    }

    private func range(_ t: Tweak) -> String {
        switch (t.minOS, t.maxOS) {
        case (nil, nil): return "Any supported iOS"
        case (let a?, nil): return "iOS \(a)+"
        case (nil, let b?): return "up to iOS \(b)"
        case (let a?, let b?): return "iOS \(a)–\(b)"
        }
    }
}

struct PresetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let id: String
    var body: some View {
        if let p = Preset.all.first(where: { $0.id == id }) {
            List {
                Section { VStack(alignment: .leading, spacing: 6) { Text(p.title).font(.system(size: 22, weight: .bold)).foregroundStyle(t.ink); Text(p.detail).foregroundStyle(t.ink2); Tag(style: p.tier.tag) } }.rowCard()
                Section("Includes") {
                    ForEach(p.tweaks) { tw in
                        NavigationLink(value: StudioRoute.gild(.tweak(tw.id))) {
                            HStack { Text(tw.title).foregroundStyle(t.ink); Spacer(); Tag(style: tw.tier.tag) }
                        }
                    }
                }.rowCard()
            }
            .themedList()
            .navigationTitle("Preset")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    ReviewBar()
                    Button { model.tweaks.apply(preset: p); Haptics.selection(); model.show(Toast(kind: .info, title: "\(p.tweaks.count) staged", subtitle: "Review to apply.", symbol: "checklist")) } label: { Text("Stage this preset") }
                        .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
                }.padding(.bottom, 8).background(.bar)
            }
        }
    }
}
