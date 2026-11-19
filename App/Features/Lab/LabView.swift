import SwiftUI

struct LabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t

    var body: some View {
        List {
            Section {
                Button { Task { await model.runCheck() } } label: {
                    HStack {
                        Label("Run device check", systemImage: "stethoscope").font(.body.weight(.semibold))
                        Spacer()
                        if model.checking { ProgressView() }
                        else if let d = model.lastCheck { Text(d, style: .relative).font(.footnote).foregroundStyle(t.ink3) }
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
                NavigationLink(value: LabRoute.displayCheck) { Label("Clock & Lock Screen", systemImage: "clock") }
                NavigationLink(value: LabRoute.minis) { Label("Analyse with Minis", systemImage: "doc.text.magnifyingglass") }
                NavigationLink(value: LabRoute.diagnose) { Label("Diagnose a problem", systemImage: "text.magnifyingglass") }
                NavigationLink(value: LabRoute.bench) { Label("Test bench", systemImage: "checklist") }
                NavigationLink(value: LabRoute.crashReview) { Label("Read a crash report", systemImage: "doc.text.magnifyingglass") }
                NavigationLink(value: LabRoute.history) {
                    HStack {
                        Label("Undo history", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(model.receipts.receipts.count)").foregroundStyle(t.ink3).monospacedDigit()
                    }
                }
                NavigationLink(value: LabRoute.bluetooth) { Label("Bluetooth notebook", systemImage: "dot.radiowaves.left.and.right") }
                NavigationLink(value: LabRoute.network) { Label("Local network", systemImage: "network") }
                NavigationLink(value: LabRoute.fileVault) { Label("File Vault", systemImage: "tray.full") }
            }.rowCard()

            if let snap = model.snapshot {
                Section {
                    ForEach(snap.facts) { FactRow(fact: $0) }
                } header: {
                    HStack { Text("Device passport"); Spacer(); if snap.isDemo { Text("Demo") } }
                } footer: {
                    Text("Observed values come from the selected device. Unknown means the value isn’t available.")
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
    ]
}
