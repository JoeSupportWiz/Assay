import SwiftUI
import UniformTypeIdentifiers

struct CrashReviewView: View {
    @State private var picking = false
    @State private var reading = false
    @State private var evidence: CrashEvidence?
    @State private var sample = false
    @State private var notice: String?

    var body: some View {
        List {
            Section("Find one report") {
                Text("In Settings → Privacy & Security → Analytics & Improvements → Analytics Data, open the app crash report for the time in question.")
                Text("Use Share → Save to Files → On My iPhone. Choose that .ips file below. You don’t need to collect a sysdiagnose archive or turn on analytics sharing.")
            }.rowCard()
            Section {
                Button("Choose .ips file", systemImage: "doc") {
                    reset()
                    picking = true
                }
                Button("Try a synthetic example", systemImage: "text.document") {
                    reset()
                    sample = true
                    evidence = try? CrashReview.parse(CrashReview.sample)
                }
            } footer: {
                Text("One local file, up to 5 MiB. Assay reads it on this device without saving a copy.")
            }.rowCard().disabled(reading)
            if reading { ProgressView("Reading report…") }
            if let notice { Text(verbatim: notice) }
            if let evidence {
                Section(sample ? "Synthetic example" : "Observed in the report") {
                    Text(verbatim: evidence.summary)
                    Text("Unknown means a value was unrecognised or could not be verified. Unavailable means the information was not supplied.")
                        .foregroundStyle(.secondary)
                }.rowCard()
                Section("What this tells you") {
                    Text("These fields describe how execution stopped. They do not identify a root cause or establish the health of your device.")
                    if !sample {
                        NavigationLink("Review summary for sharing") {
                            List {
                                Section("Everything that will be shared") { Text(verbatim: evidence.summary) }.rowCard()
                                ShareLink(item: evidence.summary) { Label("Share this text only", systemImage: "square.and.arrow.up") }
                            }.themedList().navigationTitle("Review summary")
                        }
                    }
                    Button("Clear review") { reset() }
                }.rowCard()
            }
        }
        .themedList()
        .navigationTitle("Crash review")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picking, allowedContentTypes: [UTType(filenameExtension: "ips") ?? .data]) { result in
            switch result {
            case .success(let url):
                reading = true
                Task { @MainActor in
                    let loaded = await Task.detached(priority: .utility) {
                        Result { try CrashReview.read(url) }
                    }.value
                    switch loaded {
                    case .success(let report): evidence = report
                    case .failure(let error): notice = ((error as? CrashReviewError) ?? .file).rawValue
                    }
                    reading = false
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { notice = CrashReviewError.file.rawValue }
            }
        }
    }

    private func reset() {
        evidence = nil
        notice = nil
        sample = false
    }
}
