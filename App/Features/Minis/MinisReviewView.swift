import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Push inside the existing NavigationStack. Preparing a report does not hand it off.
@MainActor
struct MinisReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var choosingLog = false
    @State private var logSummary: MinisTransport?
    @State private var loadingLog = false
    @State private var logGeneration = UUID()
    @State private var exportName = "assay-minis-report"
    @State private var includeReceipts = false
    @State private var request: Request?
    @State private var document: MinisDocument?
    @State private var showingPreview = false
    @State private var reviewed = false
    @State private var exporting = false
    @State private var notice: String?
    @State private var usedDemoHook = false

    private struct Inputs: Equatable {
        let mode: EngineMode?
        let receipts: Bool
        let log: MinisTransport?
    }
    private struct Request: Equatable {
        let id = UUID()
        let inputs: Inputs
    }
    private var inputs: Inputs { Inputs(mode: model.engineMode, receipts: includeReceipts, log: logSummary) }
    private var current: MinisDocument? { request?.inputs == inputs ? document : nil }
    private var ready: MinisDocument? { reviewed ? current : nil }
    private var preparing: Bool { request != nil && document == nil }
    private var mode: EngineMode { model.engineMode ?? .demo }

    var body: some View {
        List {
            Section {
                source
                Toggle("Include receipt summaries", isOn: $includeReceipts)
                if mode != .demo {
                    if let summary = logSummary {
                        Text("Imported log: \(summary.heartbeatSamples) backup samples · \(summary.explicitResetLines) reset lines")
                        Button("Remove log summary") { logSummary = nil }
                    } else {
                        Button(loadingLog ? "Reading log…" : "Add backup log summary (optional)") { choosingLog = true }.disabled(loadingLog)
                    }
                }
                Button(action: prepare) {
                    if preparing { ProgressView("Preparing JSON…") }
                    else { Label(current == nil ? "Prepare report" : "Prepare a new report", systemImage: "doc.text") }
                }
                .disabled(preparing || loadingLog)
                if current != nil {
                    Button("Review JSON", systemImage: "doc.text.magnifyingglass") { showingPreview = true }
                }
            } header: { Text("Report contents") } footer: {
                Text("Preparing reads a snapshot. It doesn’t change settings, save a file or send anything to Minis or an AI provider.")
            }.rowCard()

            Section {
                Button("Copy report and open Minis", systemImage: "arrow.up.forward.app") {
                    guard let ready, let url = URL(string: "minis://action/new_chat") else { return }
                    copy(Self.prompt + "\n\n" + ready.text)
                    openURL(url) { ok in if !ok { notice = "Report copied. Open Minis manually and paste it into a chat." } }
                }
                ShareLink(item: ready?.text ?? "") { Label("Share reviewed JSON", systemImage: "square.and.arrow.up") }
                Button("Copy reviewed JSON", systemImage: "doc.on.doc") {
                    guard let ready else { return }
                    copy(ready.text)
                    notice = "Reviewed JSON copied. Paste it into the chat you choose."
                }
            } header: { Text("Share with Minis") } footer: {
                Text("Copy and open starts a Minis chat; paste and send when ready. Alternatively, share to Minis or attach the saved file to this chat. Your chosen Minis model may be hosted. No automatic upload.")
            }.disabled(ready == nil).rowCard()

            Section {
                Button("Save JSON to Files", systemImage: "folder") { exporting = ready != nil }
                    .disabled(ready == nil)
            } header: { Text("Files export") } footer: {
                Text("For optional read-only MCP access, choose the Assay Reports folder you set up in Minis. Otherwise, save anywhere you choose. Assay runs no live server or background sync. A file is exported only when you save it.")
            }.rowCard()

            Section {
                DisclosureGroup("Optional analysis prompt") {
                    Text(verbatim: Self.prompt).font(.callout).textSelection(.enabled)
                    Button("Copy prompt only", systemImage: "doc.on.doc") {
                        copy(Self.prompt)
                        notice = "Prompt copied without report data."
                    }
                }
            } footer: { Text("Separate from the report. Paste into your chat if useful.") }.rowCard()
        }
        .listStyle(.insetGrouped)
        .themedList()
        .navigationTitle("Minis report")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.engineMode) { logGeneration = UUID(); logSummary = nil; loadingLog = false; invalidate() }
        .onChange(of: inputs) { invalidate() }
        .task(id: request) { [request] in
            if let request, document == nil { await capture(request) }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if !usedDemoHook, args.contains("-uiDemo"), args.contains("-minisReportPreview"),
               model.engineMode == .demo, !includeReceipts {
                usedDemoHook = true
                prepare()
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let current { preview(current) }
        }
        .fileImporter(isPresented: $choosingLog, allowedContentTypes: [.data]) { result in
            guard case .success(let url) = result else { return }
            let token = UUID(); logGeneration = token; loadingLog = true; invalidate()
            Task {
                let summary = await Task.detached(priority: .utility) { try? MinisTransport.fromFile(url) }.value
                guard token == logGeneration, mode != .demo else { return }
                loadingLog = false; logSummary = summary
                if summary == nil { notice = "No recognised backup events. Choose a UTF-8 app or minimuxer log of 8 MB or less. Nothing was saved or shared." }
            }
        }
        .fileExporter(isPresented: $exporting, document: ready, contentType: .json,
                      defaultFilename: exportName) { result in
            switch result {
            case .success: notice = "Reviewed JSON saved to Files."
            case .failure(let error):
                let nsError = error as NSError
                guard nsError.domain != NSCocoaErrorDomain || nsError.code != NSUserCancelledError else { return }
                notice = "Couldn’t save the file. Try another folder, share the JSON or copy it into your chat."
            }
        }
        .alert("Minis report", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(notice ?? "") }
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 6) {
            Tag(style: .neutral, text: mode == .demo ? "Demo · sample data" : "Real · local iPhone data")
            Text(limits).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var limits: String {
        switch mode {
        case .demo: "Clock findings and backup progress are examples, not observations from your iPhone."
        case .iphone: "Assay can read public device facts, not system preferences or backup progress. Missing evidence does not rule out a problem."
        case .mac: "The Mac companion is unavailable in this build. Only local iPhone facts are available, not Mac backup history or system preferences."
        }
    }

    private func preview(_ document: MinisDocument) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    source
                    Text("This is the complete JSON. Sharing and copying use this text; Files saves the same bytes.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    Text(verbatim: document.text)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding()
            }
            .navigationTitle("Review JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { showingPreview = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this report") { reviewed = current != nil; showingPreview = false }
                }
            }
        }
    }

    private func prepare() {
        invalidate()
        request = Request(inputs: inputs)
    }

    private func invalidate() {
        request = nil
        document = nil
        reviewed = false
        showingPreview = false
        exporting = false
        notice = nil
    }

    // The engine can suspend without respecting cancellation. Check identity AND live inputs
    // before touching the model or publishing either a result or an error.
    private func accepts(_ candidate: Request) -> Bool {
        !Task.isCancelled && request == candidate && inputs == candidate.inputs
    }

    private func capture(_ candidate: Request) async {
        guard accepts(candidate) else { return }
        do {
            var report = try await MinisReport.capture(from: model, includeReceipts: candidate.inputs.receipts)
            guard accepts(candidate) else { return }
            report.importedLogSummary = candidate.inputs.mode == .demo ? nil : candidate.inputs.log
            exportName = "assay-minis-report-" + String(Int(report.capturedAt.timeIntervalSince1970)) + "-" + String(UUID().uuidString.prefix(6))
            document = try MinisDocument(data: report.encoded())
            showingPreview = true
        } catch {
            guard accepts(candidate) else { return }
            invalidate()
            notice = "Couldn’t prepare the report. Nothing was shared. Check the selected engine and try again."
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(180)])
    }

    private static let prompt = """
    Analyse only the attached Assay report. Identify its source first; don’t treat Demo data as evidence about my phone. Cite the JSON fields behind each conclusion and distinguish observations, hypotheses and unknowns.

    For a clock stuck at 09:41, what would distinguish a display override from incorrect system time? For a slow or stalled backup, what do the recorded progress, power and thermal facts actually establish? Don’t infer a trend from a single snapshot. Rank plausible explanations, note missing evidence and suggest read-only checks I can make next. Don’t run commands or change settings.
    """
}
