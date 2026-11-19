import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        List {
            Section {
                deviceRow
            }.rowCard()

            if let attention = attentionFindings.first {
                Section("Needs attention") {
                    Button { open(attention) } label: { FindingRow(finding: attention) }
                    if attentionFindings.count > 1 {
                        Button { model.selectedTab = .lab; model.labPath = [.diagnose] } label: {
                            Text("\(attentionFindings.count - 1) more in Lab").foregroundStyle(t.ink2)
                        }
                    }
                }.rowCard()
            }

            Section("Device") {
                if let snap = model.snapshot, let score = snap.healthScore {
                    LabeledContent("Health") { Text("\(score) / 100").monospacedDigit() }
                } else {
                    LabeledContent("Health") { Text("Run a check").foregroundStyle(t.ink3) }
                }
                if let b = model.snapshot?.backup { backupRow(b) }
                LabeledContent("Verified preference changes") { Text("\(model.receipts.verifiedChangeCount(engine: model.engine.mode))").monospacedDigit() }
            }.rowCard()

            Section("Shortcuts") {
                Button { model.selectedTab = .lab; model.labPath = [.diagnose] } label: {
                    Label("Diagnose a problem", systemImage: "text.magnifyingglass")
                }
                Button { model.selectedTab = .lab; model.labPath = [.history] } label: {
                    Label("Undo history", systemImage: "clock.arrow.circlepath")
                }
                Button { Task { await model.runCheck() } } label: {
                    HStack {
                        Label("Run device check", systemImage: "stethoscope")
                        if model.checking { Spacer(); ProgressView() }
                    }
                }.disabled(model.checking)
            }.rowCard()
        }
        .themedList()
        .navigationTitle(model.userName.isEmpty ? "Home" : "Hi, \(model.userName)")
        .navigationBarTitleDisplayMode(.large)
        .task { if model.lastCheck == nil { await model.runCheck() } }
        .refreshable { await model.runCheck() }
    }

    private var attentionFindings: [Finding] { model.findings.filter { $0.fix != nil } }

    private func open(_ f: Finding) {
        if let id = f.symptomID { model.selectedTab = .lab; model.labPath = [.diagnose, .symptom(id)] }
    }

    private var deviceRow: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "iphone", hue: .sky, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.snapshot?.name ?? "This iPhone").font(.system(size: 17, weight: .semibold)).foregroundStyle(t.ink)
                Text(subtitle).font(.system(size: 13.5)).foregroundStyle(t.ink2)
            }
            Spacer()
            if model.snapshot?.isDemo == true { Tag(style: .neutral, text: "Demo") }
        }
    }

    private var subtitle: String {
        guard let s = model.snapshot else { return "Reading…" }
        return "iOS \(s.osVersion) · \(model.engine.displayName)"
    }

    private func backupRow(_ b: BackupStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch b.phase {
            case .running(let p):
                HStack { Text("Backup"); Spacer(); Text("\(Int(p * 100))%").monospacedDigit().foregroundStyle(t.ink2) }
                ProgressView(value: p).tint(t.accentColor)
            case .paused:
                LabeledContent("Backup") { Text("Paused") }
            case .done(let d):
                LabeledContent("Backup") { Text(d, style: .relative) }
            case .none:
                LabeledContent("Backup") { Text("None yet").foregroundStyle(t.ink3) }
            }
        }
    }
}
