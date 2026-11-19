import SwiftUI
import UniformTypeIdentifiers

@MainActor public struct USBBackupHandoffView: View {
    @State private var job: USBJob?
    @State private var document: USBRequestDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var selectedJob: USBPending?
    @State private var abandoning = false
    @State private var reading = false
    @State private var launcherHelp = false
    @State private var notice = ""

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink { MacBackupToolsView() } label: { Label("Get the Mac helper",systemImage:"arrow.down.circle") }
                Text("A standard USB backup, not protective system rollback. The backup stays on your Mac; only a request and a receipt move through Files.")
            }
            if let job {
                switch job {
                case .idle:
                    Section("1. Prepare a request") { createButton(job) }
                case .pending(let pending):
                    Section("1. Send the pending request") {
                        Button("Save request to Files") { export(pending) }
                        Text("Choose On My iPhone, then touch and hold the saved JSON in Files and choose Share → AirDrop. Or save it in a folder you share with your Mac.")
                    }
                    macStep
                    Section("3. Return the receipt") {
                        Text("After the helper stops, find the result JSON beside the request on your Mac. AirDrop it back and save it to Files, or open the shared folder here. Do not send the backup folder.")
                        if reading { ProgressView("Reading receipt…") }
                        else { Button("Import result from Files") { selectedJob = pending; importing = true } }
                    }
                    Section {
                        Button("Abandon pending request", role: .destructive) { selectedJob = pending; abandoning = true }
                    }
                case .received(let receipt):
                    Section("Mac-reported result") {
                        Text(receipt.outcome.rawValue.capitalized).font(.headline)
                        Text(detail(receipt.outcome))
                        LabeledContent("Started", value: receipt.started.formatted())
                        LabeledContent("Finished", value: receipt.finished.formatted())
                    }
                    Section { createButton(job) } footer: { Text("A new request replaces the result stored here.") }
                }
            } else {
                Button("Reload local request") { reload() }
            }
            if !notice.isEmpty { Section { Text(notice) } }
            Section("About this handoff") {
                Text("This is a Mac-reported result, not a paired or live connection. The receipt is not cryptographically authenticated and cannot prove complete data recovery. Only import a receipt from your own Mac.")
                Text("Assay keeps only the pending request or latest result on this iPhone. Nothing is sent automatically.")
            }
        }
        .disabled(reading)
        .navigationTitle("USB backup handoff")
        .onAppear { reload() }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "Assay-USB-request.json") { result in
            document = nil
            switch result {
            case .success: notice = "Request saved. Open it with the helper on your Mac."
            case .failure(let error):
                if !cancelled(error) { notice = "Request not saved. Choose another folder in Files." }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): if let selectedJob { receive(url, for: selectedJob) }
            case .failure(let error): if !cancelled(error) { notice = "Receipt not opened. Try choosing it again in Files." }
            }
        }
        .confirmationDialog("Abandon this request?", isPresented: $abandoning, titleVisibility: .visible, presenting: selectedJob) { pending in
            Button("Abandon request", role: .destructive) { change { try $0.abandon(pending) } }
            Button("Keep request", role: .cancel) {}
        } message: { _ in Text("This iPhone will reject its receipt. This does not stop a backup already running on your Mac.") }
        .sheet(isPresented: $launcherHelp) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Start on your Mac").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text("In Finder, unzip the Mac helper and open the extracted folder. If you have the Assay source instead, open Mac → usb-backup. Double-click Assay USB Backup.command, not the request JSON. Keep the launcher with its helper files.")
                Text("In the file chooser, select the request from Downloads or your shared folder. Follow the Terminal prompts to choose a private local backup folder and confirm before writing.")
                Button("Done") { launcherHelp = false }.buttonStyle(.borderedProminent)
            }.padding()
        }
    }

    private var macStep: some View {
        Section("2. Start on your Mac") {
            Text("Connect this iPhone to your Mac by USB, unlock it, and approve Trust if asked. In Finder, open the extracted Mac helper folder (or Mac → usb-backup in the Assay source) and double-click [Assay USB Backup.command](assay-help:usb-launcher). Select the request and confirm the backup on your Mac.")
                .environment(\.openURL, OpenURLAction { _ in launcherHelp = true; return .handled })
        }
    }

    private func detail(_ outcome: USBReceipt.Outcome) -> String {
        switch outcome {
        case .completed: return "The Mac reports that the backup tool succeeded and verified a fresh manifest. No restore was tested."
        case .unverified: return "The Mac reports that the tool succeeded but a fresh manifest was not verified. Keep a known-good backup."
        case .failed: return "The Mac reports a failed backup. Check the cable, trust and free disk space before making a new request."
        case .cancelled: return "The Mac reports cancellation. A partial backup may remain; make a new request if you want to retry."
        }
    }

    private func createButton(_ previous: USBJob) -> some View {
        Button("Create and export request") {
            change { try $0.create(replacing: previous) }
            if case .pending(let pending) = job, notice.isEmpty { export(pending) }
        }
    }

    private func export(_ pending: USBPending) {
        document = USBRequestDocument(pending)
        notice = ""
        exporting = true
    }

    private func receive(_ url: URL, for pending: USBPending) {
        reading = true
        Task {
            defer { reading = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) { try USBRequestDocument.readReceipt(at: url) }.value
                change { try $0.accept(data, for: pending) }
            } catch { notice = "Cannot read that receipt. Choose a small result JSON from Files." }
        }
    }

    private func reload() {
        do { job = try USBJobStore.local().load(); notice = "" }
        catch { job = nil; notice = "Local handoff unavailable. Unlock this iPhone and try again." }
    }

    private func change(_ operation: (USBJobStore) throws -> USBJob) {
        do { job = try operation(USBJobStore.local()); notice = "" }
        catch {
            reload()
            switch error {
            case USBFault.time: notice = "Receipt times are invalid for this request. Check both clocks and choose the current receipt."
            case USBFault.wrongJob, USBFault.changed: notice = "This request is no longer current or the receipt belongs to another request."
            case USBFault.format, USBFault.size, is DecodingError: notice = "Not a valid result. Choose the result JSON from your Mac, not the request."
            default: notice = "Could not update the local handoff. Unlock this iPhone and retry."
            }
        }
    }

    private func cancelled(_ error: Error) -> Bool {
        let e = error as NSError
        return e.domain == NSCocoaErrorDomain && e.code == NSUserCancelledError
    }
}
