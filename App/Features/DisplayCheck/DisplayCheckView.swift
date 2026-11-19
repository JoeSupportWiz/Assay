import SwiftUI
import UniformTypeIdentifiers

/// Device wall clock comes from Foundation. The status bar is *reported by the person*, not read from SpringBoard.
struct DisplayCheckView: View {
    @State private var typed = ""
    @State private var trusted = ""
    @State private var clock = DisplayClockReport()
    @State private var clockError = ""
    @State private var lineReport: String?
    @State private var lineTime: Date?
    @State private var evidence: DisplayImportEvidence?
    @State private var picking = false
    @State private var reading = false
    @State private var error = ""
    @State private var ready = false
    private enum Field: Hashable { case status, reference }
    @FocusState private var field: Field?

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.date, format: .dateTime.hour().minute().second()).font(.largeTitle.monospacedDigit())
                        Text("Device time · \(TimeZone.current.identifier)").font(.footnote).foregroundStyle(.secondary)
                    }.accessibilityElement(children: .combine)
                }
            } header: { Text("Device clock now") } footer: {
                Text("Read the status bar at the very top of the phone, not the clock above. Assay can read device time, but not the status bar.")
            }
            if clock.samples.count < 2 {
                Section {
                    if clock.samples.isEmpty || ready {
                        Text("Enter what you see now. If available, also check a separate clock you trust for your current location. Don’t copy this phone’s time.")
                        VStack(alignment: .leading) {
                            Text("Status bar time")
                            TextField("Status bar time", text: $typed, prompt: Text("9:41 or 14:26"))
                                .focused($field, equals: .status)
                        }
                        VStack(alignment: .leading) {
                            Text("Trusted local time (optional)")
                            TextField("Trusted local time, 24-hour", text: $trusted, prompt: Text("24-hour, e.g. 21:41"))
                                .focused($field, equals: .reference)
                        }
                        if !clockError.isEmpty { Text(clockError) }
                        Button("Record reading \(clock.samples.count + 1)") { record() }
                    } else {
                        Text("Wait one minute. The fields will reopen for a fresh reading; record it within 10 minutes of the first.")
                    }
                } header: { Text("Reading \(clock.samples.count + 1) of 2") }
                .keyboardType(.numbersAndPunctuation)
            }
            if !clock.samples.isEmpty {
                Section("Clock findings") {
                    Text(clock.summary)
                    if let elapsed = clock.elapsedDescription { Text(elapsed) }
                    ForEach(Array(clock.samples.enumerated()), id: \.offset) { i, sample in
                        VStack(alignment: .leading) {
                            Text("Reading \(i + 1)").font(.headline)
                            Text(sample.displayDetails)
                        }.accessibilityElement(children: .combine)
                    }
                    Button("Clear clock readings", role: .destructive) {
                        clock = DisplayClockReport(); typed = ""; trusted = ""; clockError = ""; ready = false; field = nil
                    }
                }
            }
            Section {
                Button { picking = true } label: { Label(reading ? "Reading…" : "Check a GoldenNugget log", systemImage: "doc.text.magnifyingglass") }.disabled(reading)
                if let e = evidence {
                    LabeledContent("Complete preset lists", value: String(e.records))
                    if e.records > 0 {
                        LabeledContent("Recording status override", value: "\(e.recordingRecords)/\(e.records)")
                        LabeledContent("Unlock indicator (red/green line)", value: "\(e.authLineRecords)/\(e.records)")
                        Text("Last complete list: recording override \(e.lastRecording ? "listed" : "not listed"); unlock indicator \(e.lastAuthLine ? "listed" : "not listed").")
                    } else { Text("No complete preset lists found. This does not tell you whether either setting is enabled.") }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.secondary) }
            } header: { Text("Look for the two known settings") } footer: {
                Text("Only exact names in complete preset-import lists count. Repeated imports may be the same preset. This is historical evidence, not a read-back from the phone.")
            }
            Section {
                Menu(lineReport ?? "Record what you see") {
                    ForEach(["Green line", "Red line", "No line", "Not sure"],id: \.self) { value in Button(value) { lineReport=value; lineTime=Date() } }
                }
                if let d=lineTime { Text("Reported by you at \(d.formatted(date: .omitted,time:.shortened)).").font(.footnote) }
            } header: { Text("Lock Screen line") } footer: { Text("This observation is separate from the clock and from the preset log. Assay cannot inspect the live Lock Screen.") }
            Section("What to do next") {
                Text("If device time is right and the status time differs, first stop any active screen recording or mirroring and compare again. Don’t change Date & Time just to remove a display override.")
                Text("If you enabled the unlock-test indicator or recording-status override in another app, use that app’s undo or targeted reset for that setting. Don’t select a whole-device reset. If the source tool can’t restore the original value, this app can’t safely invent it.")
                Text("If the device time itself is wrong against a trusted clock, check Settings → General → Date & Time, including the time zone.")
            }
            if !clock.samples.isEmpty || evidence != nil || lineReport != nil {
                Section { ShareLink(item: report) { Label("Share check summary", systemImage: "square.and.arrow.up") } } footer: { Text("These observations are not saved by Assay. Share before leaving to keep a copy. Includes reading times, time zones and any line report or preset counts, never the imported log.") }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task(id: clock.samples.count) {
            guard clock.samples.count == 1, let first = clock.samples.first else { return }
            do {
                try await Task.sleep(until: first.instant.advanced(by: .seconds(60)), clock: .continuous)
                try Task.checkCancellation()
                ready = true
            } catch { /* Dismissing or clearing the check cancels the wait. */ }
        }
        .themedList().navigationTitle("Clock & Lock Screen").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.data]) { res in
            guard case .success(let url) = res else { return }
            reading = true; evidence = nil; error = ""
            Task {
                let parsed = await Task.detached(priority: .utility) { () -> DisplayImportEvidence? in
                    let scoped=url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let handle=try? FileHandle(forReadingFrom:url) else { return nil }; defer { try? handle.close() }
                    let max = 8 * 1024 * 1024
                    do {
                        var data = Data()
                        while data.count <= max, let chunk = try handle.read(upToCount: min(65_536, max + 1 - data.count)), !chunk.isEmpty { data.append(chunk) }
                        guard data.count <= max, !data.contains(0), let text=String(data:data,encoding:.utf8) else { return nil }
                        return DisplayImportEvidence.parse(text)
                    } catch { return nil }
                }.value
                reading = false; evidence = parsed
                if parsed == nil { error = "Couldn’t read that file. Choose a UTF-8 log up to 8 MiB. No data was changed." }
            }
        }
    }
    private func record() {
        do {
            try clock.record(status: typed, reference: trusted)
            typed = ""; trusted = ""; field = nil; clockError = ""; ready = false
        } catch { clockError = error.localizedDescription }
    }
    private var report: String {
        var rows = ["Assay · Clock & Lock Screen (read-only)", clock.text]
        if let lineReport, let lineTime { rows.append("\(lineTime.ISO8601Format()) · Lock Screen, user-reported: \(lineReport). Not read from system preferences.") }
        if let e=evidence {rows.append("Historical preset imports: \(e.records). Recording override listed: \(e.recordingRecords). Unlock indicator listed: \(e.authLineRecords). No current preference value observed.")}
        return rows.joined(separator:"\n")
    }
}
