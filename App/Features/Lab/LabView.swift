import SwiftUI

struct LabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var checking = false

    var body: some View {
        Screen(title: "Lab", subtitle: "Know what's really happening on your iPhone.") {
            Button { runCheck() } label: {
                HStack(spacing: 14) {
                    GlyphTile(symbol: "stethoscope", hue: .mint, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Device check").font(.system(size: 18, weight: .bold)).foregroundStyle(t.heroInk)
                        Text(checking ? "Reading device…" : "Reads only · changes nothing").font(.system(size: 13)).foregroundStyle(t.heroInk.opacity(0.7))
                    }
                    Spacer()
                    if checking { ProgressView().tint(t.heroInk) }
                    else { Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold)).foregroundStyle(t.heroInk) }
                }
                .padding(18).card(fill: t.hero)
            }.buttonStyle(PressStyle()).padding(.top, 18).rise(1)

            if let snap = model.snapshot {
                SectionHeader(title: "Device passport", trailing: snap.isDemo ? "Demo" : nil).rise(2)
                VStack(spacing: 0) {
                    ForEach(Array(snap.facts.enumerated()), id: \.element.id) { i, f in
                        FactRow(fact: f)
                        if i < snap.facts.count - 1 { Divider().padding(.leading, 16) }
                    }
                }.card().rise(3)
                HStack(spacing: 6) {
                    Tag(style: .observed); Text("read from iOS").foregroundStyle(t.ink2)
                    Tag(style: .unknown); Text("iOS doesn't say").foregroundStyle(t.ink2)
                }.font(.system(size: 12)).padding(.top, 10).rise(4)
            }

            SectionHeader(title: "Tools").rise(5)
            VStack(spacing: 0) {
                ForEach(LabTool.allCases) { tool in
                    Row(icon: tool.symbol, hue: tool.hue, title: tool.title, subtitle: tool.subtitle) {
                        Tag(style: .neutral, text: tool.phase)
                    }
                    if tool != LabTool.allCases.last { Divider().padding(.leading, 68) }
                }
            }.card().rise(6)
        }
    }

    private func runCheck() {
        guard !checking else { return }
        checking = true
        Task {
            await model.refresh()
            try? await Task.sleep(for: .milliseconds(600))
            checking = false
            model.show(Toast(kind: .success, title: "Device check complete", subtitle: "\(model.snapshot?.facts.count ?? 0) facts read · nothing changed"))
        }
    }
}

struct FactRow: View {
    @Environment(\.theme) private var t
    let fact: Fact
    var body: some View {
        HStack(spacing: 10) {
            Text(fact.label).font(.system(size: 14.5, weight: .medium)).foregroundStyle(t.ink)
            Spacer()
            Text(fact.value).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(t.ink).multilineTextAlignment(.trailing)
            switch fact.evidence {
            case .observed: Tag(style: .observed, text: "Obs")
            case .inferred(let p): Tag(style: .inferred(p), text: "\(p)%")
            case .unknown: Tag(style: .unknown, text: "?")
            }
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
    }
}

enum LabTool: String, CaseIterable, Identifiable {
    case diagnose, vault, ble, network, timeline
    var id: String { rawValue }
    var title: String {
        switch self { case .diagnose: "Diagnose a symptom"; case .vault: "Vault · backups"; case .ble: "Bluetooth notebook"; case .network: "Local network"; case .timeline: "Change timeline" }
    }
    var subtitle: String {
        switch self {
        case .diagnose: "e.g. clock stuck at 09:41, green line"
        case .vault: "Backups, receipts, undo"
        case .ble: "RSSI, services, history"
        case .network: "Bonjour, latency, TLS"
        case .timeline: "Everything Assay changed"
        }
    }
    var symbol: String {
        switch self { case .diagnose: "text.magnifyingglass"; case .vault: "tray.full"; case .ble: "dot.radiowaves.left.and.right"; case .network: "network"; case .timeline: "clock.arrow.circlepath" }
    }
    var hue: ModuleHue { switch self { case .diagnose: .lilac; case .vault: .butter; case .ble: .sky; case .network: .mint; case .timeline: .peach } }
    var phase: String { switch self { case .diagnose: "1.4"; case .vault: "3.4"; case .ble: "7.1"; case .network: "7.2"; case .timeline: "1.2" } }
}
