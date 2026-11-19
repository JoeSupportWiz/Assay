import SwiftUI
import UniformTypeIdentifiers

/// Device wall clock comes from Foundation. The status bar is *reported by the person*, not read from SpringBoard.
struct DisplayCheckView: View {
    @State private var typed = ""
    @State private var sample: DisplayClockSample?
    @State private var older: DisplayClockSample?
    @State private var evidence: DisplayImportEvidence?
    @State private var picking = false
    @State private var reading = false
    @State private var error = ""
    @FocusState private var editing: Bool

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.date, format: .dateTime.hour().minute().second()).font(.largeTitle.monospacedDigit())
                        Text("Device time · \(TimeZone.current.identifier)").font(.footnote).foregroundStyle(.secondary)
                    }.accessibilityElement(children: .combine)
                }
                Button("My status bar shows 9:41") { compare("09:41") }
                HStack {
                    TextField("Other time, e.g. 14:26", text: $typed).focused($editing).keyboardType(.numbersAndPunctuation)
                    Button("Compare") { compare(typed) }.disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let sample {
                    Label(sample.description, systemImage: sample.result == .matches ? "checkmark.circle" : "clock").accessibilityLabel(sample.description)
                    if let older, older.visible == sample.visible, older.result == .differs, sample.result == .differs,
                       sample.at.timeIntervalSince(older.at) >= 60 {
                        Text("You reported the same status time in two checks at least a minute apart while the device clock advanced. This is consistent with a fixed display override; it does not identify which setting caused it.")
                    }
                }
            } header: { Text("Compare the status bar") } footer: {
                Text("No backup needed. Look at the clock at the top of this screen, then tap its time. Assay doesn’t read the system status bar or check an internet time service.")
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
            Section("What to do next") {
                Text("If device time is right and the status time differs, first stop any active screen recording or mirroring and compare again. Don’t change Date & Time just to remove a display override.")
                Text("If you enabled the unlock-test indicator or recording-status override in another app, use that app’s undo or targeted reset for that setting. Don’t select a whole-device reset. If the source tool can’t restore the original value, this app can’t safely invent it.")
                Text("If the device time itself is wrong against a trusted clock, check Settings → General → Date & Time, including the time zone.")
            }
            if sample != nil || evidence != nil {
                Section { ShareLink(item: report) { Label("Share check summary", systemImage: "square.and.arrow.up") } } footer: { Text("Shares just these measurements and counts, never the imported log.") }
            }
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
    private func compare(_ visible: String) {
        let now=Date(); editing=false
        guard let result=DisplayClockComparison.evaluate(visible, at:now) else { error="Enter hours and minutes, e.g. 09:41 or 14:26.";return }
        older=sample;sample=DisplayClockSample(at:now,visible:visible.trimmingCharacters(in:.whitespaces),result:result);error=""
    }
    private var report: String {
        var rows=["Assay · Clock & Lock Screen (read-only)"]
        for s in [older,sample].compactMap({$0}) {rows.append("\(s.at.ISO8601Format()) · user-reported: \(s.visible) · \(s.description)")}
        if let e=evidence {rows.append("Historical preset imports: \(e.records). Recording override listed: \(e.recordingRecords). Unlock indicator listed: \(e.authLineRecords). No current preference value observed.")}
        return rows.joined(separator:"\n")
    }
}
private struct DisplayClockSample {
    let at: Date, visible: String, result: DisplayClockComparison
    var description: String {
        let time=at.formatted(.dateTime.hour().minute())
        switch result {
        case .matches: return "Your entry matches device time (\(time)) to the minute. This single check doesn’t rule out a frozen display."
        case .differs: return "You saw \(visible); the device reported \(time). They differ. Repeat in a minute to see whether the status bar moves."
        case .indeterminate: return "Your entry is one minute from device time (\(time)). A minute may have rolled over; try again."
        }
    }
}
