import SwiftUI

struct LabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        List {
            Section {
                Button { Task { await model.runCheck() } } label: {
                    HStack {
                        Label("Run device check", systemImage: "stethoscope").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        if model.checking { ProgressView() }
                        else if let d = model.lastCheck { Text(d, style: .relative).font(.system(size: 13)).foregroundStyle(t.ink3) }
                    }
                }.disabled(model.checking)
            } footer: { Text("Reads only. Changes nothing.") }.rowCard()

            if model.lastCheck != nil {
                Section("Findings") {
                    if model.findings.isEmpty {
                        Label("Nothing found", systemImage: "checkmark.circle").foregroundStyle(t.ink2)
                    } else {
                        ForEach(model.findings) { f in
                            if let id = f.symptomID, f.fix != nil {
                                NavigationLink(value: LabRoute.symptom(id)) { FindingRow(finding: f) }
                            } else {
                                FindingRow(finding: f)
                            }
                        }
                    }
                }.rowCard()
            }

            Section("Tools") {
                NavigationLink(value: LabRoute.diagnose) { Label("Diagnose a problem", systemImage: "text.magnifyingglass") }
                NavigationLink(value: LabRoute.history) {
                    HStack {
                        Label("Undo history", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(model.receipts.receipts.count)").foregroundStyle(t.ink3).monospacedDigit()
                    }
                }
                ForEach(LabTool.upcoming) { tool in
                    HStack {
                        Label(tool.title, systemImage: tool.symbol).foregroundStyle(t.ink2)
                        Spacer(); Tag(style: .neutral, text: tool.phase)
                    }
                }
            }.rowCard()

            if let snap = model.snapshot {
                Section {
                    ForEach(snap.facts) { FactRow(fact: $0) }
                } header: {
                    HStack { Text("Device passport"); Spacer(); if snap.isDemo { Text("Demo") } }
                } footer: {
                    Text("Obs = read from iOS · ? = iOS doesn't say, so Assay doesn't guess.")
                }.rowCard()
            }
        }
        .themedList()
        .navigationTitle("Lab")
    }
}

struct LabTool: Identifiable {
    let id: String, title: String, symbol: String, phase: String
    static let upcoming: [LabTool] = [
        .init(id: "vault", title: "Backups", symbol: "tray.full", phase: "Phase 3"),
        .init(id: "ble", title: "Bluetooth notebook", symbol: "dot.radiowaves.left.and.right", phase: "Phase 7"),
        .init(id: "net", title: "Local network", symbol: "network", phase: "Phase 7"),
    ]
}
