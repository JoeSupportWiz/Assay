import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var confirmNewHistory = false

    var body: some View {
        List {
            if let issue = model.receipts.storageIssue {
                Section("Undo history is paused") {
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                    Button("Read history again") { model.receipts.reload() }
                    if issue == .damaged {
                        Button("Start a new history…") { confirmNewHistory = true }
                    }
                }.rowCard()
            } else if let backup = model.receipts.lastBackupName {
                Section("New history") {
                    Text("The previous history is kept on this device as \(backup).")
                }.rowCard()
            }
            if model.receipts.storageIssue == nil {
                Section("Activity") { ReceiptCalendarView(receipts: model.receipts.receipts, engine: model.engine.mode) }.rowCard()
            }
            if model.receipts.receipts.isEmpty && model.receipts.storageIssue == nil {
                Section {
                    ContentUnavailableView("Nothing yet", systemImage: "clock.arrow.circlepath",
                        description: Text("Completed checks and changes leave receipts here. An undo is offered only for verified reversible changes."))
                }.listRowBackground(Color.clear)
            } else if model.receipts.storageIssue == nil {
                Section {
                    LabeledContent("Changes made") { Text("\(model.receipts.changeCount)").monospacedDigit() }
                    LabeledContent("Can't be undone") { Text("\(model.receipts.needsYouCount)").monospacedDigit() }
                    if let plan = model.receipts.restoreAllPlan(engine:model.engine.mode) {
                        Button { model.activePlan = plan } label: { Text("Restore to before Assay") }
                            .buttonStyle(SecondaryButtonStyle())
                            .listRowBackground(Color.clear).listRowInsets(.init())
                    }
                } footer: {
                    Text("Undo is limited to verified changes from the selected engine. If a value or its history is uncertain, Assay leaves it alone.")
                }.rowCard()

                ForEach(grouped, id: \.0) { day, items in
                    Section(day) {
                        ForEach(items) { r in
                            NavigationLink(value: LabRoute.receipt(r.id)) { row(r) }
                        }
                    }.rowCard()
                }
            }
        }
        .themedList()
        .navigationTitle("Undo history")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Start a new undo history?", isPresented: $confirmNewHistory) {
            Button("Keep existing history", role: .cancel) { }
            Button("Keep backup and start new history") { model.receipts.startNewHistory() }
        } message: {
            Text("Assay will keep the original file as a backup. The new history starts empty; old changes won’t be available to undo from it.")
        }
    }

    private var grouped: [(String, [Receipt])] {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        var order: [String] = []; var map: [String: [Receipt]] = [:]
        for r in model.receipts.receipts {
            let key = cal.isDateInToday(r.date) ? "Today" : (cal.isDateInYesterday(r.date) ? "Yesterday" : f.string(from: r.date))
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(r)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private func row(_ r: Receipt) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: symbol(r), hue: hue(r))
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title).font(.system(size: 16, weight: .medium)).foregroundStyle(t.ink)
                Text("#\(r.id) · \(r.date, style: .time) · \(r.items.count) planned")
                    .font(.system(size: 13)).foregroundStyle(t.ink2)
                HStack(spacing: 6) {
                    Tag(style: r.statusTag.0, text: r.statusTag.1)
                    if r.engine == .demo { Tag(style: .neutral, text: "Demo") }
                }
            }
        }
    }

    private func symbol(_ r: Receipt) -> String {
        switch r.kind { case .fix: "wrench.and.screwdriver"; case .tweak: "slider.horizontal.3"; case .undo: "arrow.uturn.backward"; case .scene: "square.2.layers.3d"; case .restoreAll: "arrow.counterclockwise" }
    }
    private func hue(_ r: Receipt) -> ModuleHue {
        switch r.status { case .complete: .mint; case .partial: .butter; case .failed: .peach; default: .sky }
    }
}

struct ReceiptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let id: Int

    var body: some View {
        if let r = model.receipts.receipts.first(where: { $0.id == id }) {
            List {
                Section {
                    LabeledContent("Receipt") { Text("#\(r.id)").monospacedDigit() }
                    LabeledContent("When") { Text(r.date, format: .dateTime.day().month().hour().minute()) }
                    LabeledContent("Engine") { Text(r.engine.title) }
                    LabeledContent("Result") { Tag(style: r.statusTag.0, text: r.statusTag.1) }
                    if let c = r.userConfirmed { LabeledContent("You said") { Text(c ? "It's fixed" : "Still wrong") } }
                }.rowCard()

                Section("Changes") {
                    ForEach(Array(r.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.change.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                            Tag(style: item.outcome.tag.0, text: item.outcome.tag.1)
                            HStack(spacing: 6) {
                                Text(item.change.beforeKnown ? (item.change.before?.display ?? "not set") : "unknown")
                                Image(systemName: "arrow.right").font(.system(size: 11))
                                Text(item.change.after?.display ?? "removed")
                            }.font(.system(size: 13, design: .monospaced)).foregroundStyle(t.ink2)
                            Text(item.change.target.key).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(t.ink3)
                            if let n = item.note { Text(n).font(.system(size: 13)).foregroundStyle(t.ink2) }
                        }.padding(.vertical, 2)
                    }
                }.rowCard()

                if let plan = model.receipts.undoPlan(for:r,engine:model.engine.mode) {
                    Section {
                        Button { model.activePlan = plan } label: { Text("Undo \(r.reversibleCount) change\(r.reversibleCount == 1 ? "" : "s")") }
                            .buttonStyle(SecondaryButtonStyle()).listRowBackground(Color.clear).listRowInsets(.init())
                    }
                }
            }
            .themedList()
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Receipt not found", systemImage: "doc.questionmark")
        }
    }
}
