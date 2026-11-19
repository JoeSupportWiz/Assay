import SwiftUI

// MARK: - Diagnose

struct DiagnoseView: View {
    @Environment(\.theme) private var t
    @State private var text = ""
    @State private var pending: AIPendingSend?
    @State private var requesting = false
    @State private var advice: AIDiagnosisResult?
    @State private var requestError: String?
    @FocusState private var focused: Bool

    private var ai: AIService { AIService.shared }
    private var destination: AIResolved { ai.settings.resolve(task: .diagnose) }
    private var prompt: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var busy: Bool { pending != nil || requesting }
    private var matches: [(Symptom, Int)] { Knowledge.match(text) }

    var body: some View {
        List {
            Section {
                TextField("Describe it, e.g. clock stuck at 9:41", text: $text, axis: .vertical)
                    .focused($focused)
                    .submitLabel(.search)
                    .disabled(busy)
            } footer: { Text("Catalogue matching stays on your phone. Asking for a second opinion is optional.") }.rowCard()

            if !prompt.isEmpty {
                Section(matches.isEmpty ? "No match" : "Best matches") {
                    if matches.isEmpty {
                        Text("Nothing in the catalogue matches that yet. Try different words, or pick from the list below.")
                            .font(.system(size: 14)).foregroundStyle(t.ink2)
                    }
                    ForEach(matches.prefix(4), id: \.0.id) { s, _ in row(s) }
                }.rowCard()

                secondOpinion
            }

            Section(text.isEmpty ? "Common problems" : "All problems") {
                ForEach(Knowledge.symptoms) { s in row(s) }
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Diagnose")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: text) { advice = nil; requestError = nil }
        .sheet(item: $pending) { preview in
            AIConsentSheet(pending: preview, onConfirm: { confirm(preview) }, onCancel: { pending = nil })
        }
    }

    private var secondOpinion: some View {
        Section {
            if ai.demoMode {
                Text("Demo uses local keywords. No model is contacted.")
            } else {
                LabeledContent(destination.provider.displayName, value: destination.model)
                Text(ai.privacyLabel(for: destination.provider).title).font(.footnote)
            }
            Button("Ask for a second opinion", action: ask).disabled(busy)
            if requesting { ProgressView("Checking for a known symptom…") }
            if let requestError { Text(requestError) }
            if let advice {
                if let id = advice.symptomID, let symptom = Knowledge.symptoms.first(where: { $0.id == id }) {
                    Text(symptom.title).font(.headline)
                } else {
                    Text("No known symptom identified").font(.headline)
                }
                Text(verbatim: advice.explanation)
                if let provider = advice.provider, let model = advice.model {
                    Text("Reply from \(provider.displayName) · \(model)").font(.footnote)
                }
            }
        } header: { Text("Second opinion") } footer: {
            Text("Advice only. This does not read or change device settings.")
        }.rowCard()
    }

    private func ask() {
        guard !busy, !prompt.isEmpty else { return }
        focused = false
        advice = nil
        requestError = nil
        let target = destination
        if !ai.demoMode {
            switch ai.status(for: target.provider) {
            case .needsKey: requestError = AIError.noKey.errorDescription; return
            case .notAvailable(let reason): requestError = reason; return
            case .configured: break
            }
        }
        if AIDiagnosis.needsConsent() {
            pending = AIPendingSend(provider: target.provider, model: target.model, baseURL: target.baseURL,
                                    outgoing: AIDiagnosis.outgoing(for: prompt), withContext: false)
        } else {
            requestAdvice(for: prompt)
        }
    }

    private func confirm(_ preview: AIPendingSend) {
        guard pending?.id == preview.id else { return }
        pending = nil
        guard !ai.demoMode, preview.provider == destination.provider,
              preview.model == destination.model, preview.baseURL == destination.baseURL else {
            requestError = "AI settings changed. Check the provider and model before asking again."
            return
        }
        ai.recordConsent(provider: preview.provider, withContext: false)
        requestAdvice(for: prompt)
    }

    private func requestAdvice(for description: String) {
        requesting = true
        Task { @MainActor in
            defer { requesting = false }
            do { advice = try await AIDiagnosis.suggest(text: description) }
            catch let error as AIError { requestError = error.errorDescription }
            catch { requestError = "Could not get a second opinion. Try again." }
        }
    }

    private func row(_ s: Symptom) -> some View {
        NavigationLink(value: LabRoute.symptom(s.id)) {
            HStack(spacing: 12) {
                IconTile(symbol: s.symbol, hue: .lilac)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title).font(.system(size: 16, weight: .medium)).foregroundStyle(t.ink)
                    Text(s.detail).font(.system(size: 13)).foregroundStyle(t.ink2).lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Symptom: what we found and what we'd do

struct SymptomView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    let id: String
    @State private var current: PlistValue?
    @State private var loaded = false

    private var symptom: Symptom? { Knowledge.symptoms.first { $0.id == id } }

    var body: some View {
        if let s = symptom {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.title).font(.system(size: 22, weight: .bold)).foregroundStyle(t.ink)
                        Text(s.detail).foregroundStyle(t.ink2)
                    }
                }.rowCard()

                if id == "clock-941" || id == "green-line" {
                    Section { NavigationLink(value: LabRoute.displayCheck) { Label("Check the clock and preset evidence", systemImage: "clock") } }.rowCard()
                }
                Section("What we think is happening") {
                    Text(s.cause).foregroundStyle(t.ink)
                    HStack { Tag(style: .inferred(s.confidence)); Text("Matches reports, not proof for your phone").font(.system(size: 12.5)).foregroundStyle(t.ink3) }
                }.rowCard()

                if let key = s.culprit {
                    Section("On your device") {
                        if let tw = TweakCatalog.all.first(where: { $0.target == key }) {
                            Button { model.selectedTab = .studio; model.studioPath = [.module(.gild), .gild(.tweak(tw.id))] } label: {
                                Label("Open in Gild", systemImage: "slider.horizontal.3")
                            }
                        }
                        LabeledContent("Setting") { Text(key.key).font(.system(size: 12.5, design: .monospaced)).multilineTextAlignment(.trailing) }
                        LabeledContent("Domain") { Text(key.domain).font(.system(size: 12.5, design: .monospaced)).multilineTextAlignment(.trailing) }
                        if !loaded {
                            HStack { Text("Current value"); Spacer(); ProgressView() }
                        } else if model.engine.canRead {
                            LabeledContent("Current value") {
                                HStack(spacing: 6) {
                                    Text(current?.display ?? "not set")
                                    Tag(style: .observed)
                                }
                            }
                        } else {
                            LabeledContent("Current value") { HStack(spacing: 6) { Text("Can't read yet"); Tag(style: .unknown) } }
                        }
                    }.rowCard()

                    Section {
                        EmptyView()
                    } footer: {
                        if model.engine.canRead && loaded && current != s.culpritValue {
                            Text("This setting isn't on, so it isn't the cause here.")
                        } else if !model.engine.canRead {
                            Text("This engine can't read or write yet. You can still review exactly what would change.")
                        } else {
                            Text("You'll see exactly what changes, and can do a dry run first.")
                        }
                    }
                } else {
                    Section("What helps") {
                        Text("For a whole-iPhone backup today, use Finder on a trusted Mac over USB. File Vault backs up only files you select. A reset in a log is evidence of an interrupted connection, not proof of what caused it.")
                            .foregroundStyle(t.ink)
                    }.rowCard()
                }
            }
            .themedList()
            .navigationTitle("Problem")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if s.culprit != nil {
                    Button { model.activePlan = s.plan(current: current) } label: { Text("Review the fix") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(model.engine.canRead && loaded && current != s.culpritValue)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.bar)
                }
            }
            .task(id: model.findings.count) {
                if let key = s.culprit { current = await model.engine.read(key) }
                loaded = true
            }
        } else {
            ContentUnavailableView("Unknown problem", systemImage: "questionmark.circle")
        }
    }
}

// MARK: - Fix sheet: review → run → result

struct FixSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    let plan: OperationPlan

    enum Phase: Equatable { case review, running(OperationRunner.Stage), result(Int) }
    @State private var phase: Phase = .review
    @State private var dryRun = false
    @State private var understood = false
    @State private var receipt: Receipt?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .review: review
                case .running(let s): running(s)
                case .result: result
                }
            }
            .themedList()
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .running = phase { EmptyView() } else { Button(receipt == nil ? "Cancel" : "Done") { dismiss() } }
                }
            }
        }
        .interactiveDismissDisabled({ if case .running = phase { return true } else { return false } }())
    }

    // MARK: Review

    private var review: some View {
        List {
            Section("What will change") {
                ForEach(plan.changes) { c in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(c.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink); Spacer(); Tag(style: c.tier.tag) }
                        diff(c)
                        Text("\(c.target.domain) › \(c.target.key)").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(t.ink3)
                    }.padding(.vertical, 2)
                }
            }.rowCard()

            Section("Safety") {
                Label("Current values are read again right before writing.", systemImage: "arrow.triangle.2.circlepath")
                Label(plan.changes.allSatisfy(\.beforeKnown) ? "Every change can be undone from Undo history." : "Some values can't be read first, so those can't be undone.",
                      systemImage: plan.changes.allSatisfy(\.beforeKnown) ? "arrow.uturn.backward.circle" : "exclamationmark.triangle")
                if plan.needsRespring { Label("The original change normally requires restarting SpringBoard. This preview won’t restart it.", systemImage: "arrow.clockwise") }
                Label(model.engine.displayName + (model.engine.mode == .demo ? " — nothing real is touched" : ""), systemImage: "iphone")
            }.font(.system(size: 14)).foregroundStyle(t.ink).rowCard()

            Section {
                if model.engine.mode != .demo {
                    Label("Preview only. This build can’t change system preferences on a real device.", systemImage: "info.circle")
                } else {
                    Toggle("Dry run (write nothing)", isOn: $dryRun)
                }
                if plan.tier >= .caution && !dryRun && model.engine.mode == .demo {
                    Toggle("I understand the risk", isOn: $understood)
                }
            } footer: { Text(plan.tier.explanation) }.rowCard()

        }
        .safeAreaInset(edge: .bottom) {
            Button { Task { await run() } } label: { Text(model.engine.mode != .demo || dryRun ? "Run preview" : "Apply in Demo") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.engine.mode == .demo && !dryRun && plan.tier >= .caution && !understood)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.bar)
        }
    }

    private func diff(_ c: Change) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            diffLine("−", c.beforeKnown ? (c.before?.display ?? "not set") : "unknown (can't read yet)", added: false)
            diffLine("+", c.after?.display ?? "removed — iOS uses its default", added: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func diffLine(_ sign: String, _ text: String, added: Bool) -> some View {
        HStack(spacing: 8) {
            Text(sign).bold()
            Text(text).lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13.5, design: .monospaced))
        .foregroundStyle(added ? (t.isDark ? Color(hex: 0x7BE8B5) : Color(hex: 0x0D5C37)) : (t.isDark ? Color(hex: 0xFFA47A) : Color(hex: 0x8A3300)))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(added ? Palette.mintDeep.opacity(0.16) : Palette.peachDeep.opacity(0.16))
    }

    // MARK: Running

    private func running(_ s: OperationRunner.Stage) -> some View {
        List {
            Section {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text(stageText(s)).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.ink).multilineTextAlignment(.center)
                    Text("Please keep Assay open.").font(.system(size: 13.5)).foregroundStyle(t.ink2)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            }.rowCard()
            Section("Steps") {
                step("Read current values", done: s != .snapshot)
                step("Write", done: { if case .writing = s { return false } else { return s == .verifying || s == .done } }(), active: { if case .writing = s { return true } else { return false } }())
                step("Read back to verify", done: s == .done, active: s == .verifying)
            }.rowCard()
        }
    }

    private func stageText(_ s: OperationRunner.Stage) -> String {
        switch s {
        case .snapshot: "Saving current values…"
        case .writing(let i, let n): "Writing \(i) of \(n)…"
        case .verifying: "Reading back to check…"
        case .done: "Done"
        }
    }

    private func step(_ title: String, done: Bool, active: Bool = false) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : (active ? "circle.dotted" : "circle")).foregroundStyle(done ? Palette.mintDeep : t.ink3)
            Text(title).foregroundStyle(done || active ? t.ink : t.ink3)
        }
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        if let r = receipt {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: icon(r)).font(.system(size: 44)).foregroundStyle(color(r))
                        Text(headline(r)).font(.system(size: 20, weight: .bold)).foregroundStyle(t.ink)
                        Text("Receipt #\(r.id)").font(.system(size: 13)).foregroundStyle(t.ink3)
                    }.frame(maxWidth: .infinity).padding(.vertical, 16)
                }.rowCard()

                Section("Result") {
                    ForEach(Array(r.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(item.change.label).foregroundStyle(t.ink); Spacer(); outcomeTag(item.outcome) }
                            if let n = item.note { Text(n).font(.system(size: 13)).foregroundStyle(t.ink2) }
                        }
                    }
                }.rowCard()

                if !r.dryRun, let q = plan.userCheck, r.status != .failed, model.receipts.receipts.first(where: { $0.id == r.id })?.userConfirmed == nil {
                    Section {
                        Text(q).foregroundStyle(t.ink)
                        Button("Yes, that's fixed") { model.receipts.confirm(r.id, ok: true); Haptics.success() }
                        Button("No, still wrong") { model.receipts.confirm(r.id, ok: false) }
                    } header: { Text("Check it yourself") } footer: {
                        Text("Assay can read the setting back, but only you can see whether the screen looks right.")
                    }.rowCard()
                } else if let c = model.receipts.receipts.first(where: { $0.id == r.id })?.userConfirmed {
                    Section { Label(c ? "You confirmed it's fixed." : "You said it's still wrong. Try the next step in Lab.", systemImage: c ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(t.ink) }.rowCard()
                }

                Section {
                    if r.dryRun && model.engine.mode == .demo {
                        Button("Apply in Demo") { receipt = nil; dryRun = false; phase = .review }.buttonStyle(PrimaryButtonStyle())
                            .listRowBackground(Color.clear).listRowInsets(.init())
                    } else if r.undoable {
                        Button("Undo this") { model.activePlan = model.receipts.undoPlan(for: r) }.buttonStyle(SecondaryButtonStyle())
                            .listRowBackground(Color.clear).listRowInsets(.init())
                    }
                }
            }
        }
    }

    private func headline(_ r: Receipt) -> String {
        switch r.status {
        case .complete: "Applied and read back"
        case .partial: "Applied, partly verified"
        case .failed: "Nothing was changed"
        case .simulated: "Dry run — nothing written"
        case .rolledBack: "Rolled back"
        }
    }
    private func icon(_ r: Receipt) -> String {
        switch r.status { case .complete: "checkmark.circle.fill"; case .partial: "exclamationmark.circle.fill"; case .failed: "xmark.circle.fill"; default: "doc.text.magnifyingglass" }
    }
    private func color(_ r: Receipt) -> Color {
        switch r.status { case .complete: Palette.mintDeep; case .partial: Palette.butterDeep; case .failed: Palette.peachDeep; default: t.ink2 }
    }
    @ViewBuilder private func outcomeTag(_ o: Receipt.Outcome) -> some View {
        switch o {
        case .verified: Tag(style: .reversible, text: "Read back OK")
        case .unverified: Tag(style: .caution, text: "Unverified")
        case .failed: Tag(style: .experimental, text: "Failed")
        case .simulated: Tag(style: .unknown, text: "Dry run")
        }
    }

    private func run() async {
        phase = .running(.snapshot)
        let r = await model.execute(plan, dryRun: dryRun || model.engine.mode != .demo) { stage in phase = .running(stage) }
        receipt = r
        phase = .result(r.id)
        if r.status == .complete { Haptics.success() } else if r.status == .failed { Haptics.error() }
    }
}
