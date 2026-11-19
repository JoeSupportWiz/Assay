import SwiftUI
import UniformTypeIdentifiers

// MARK: - Store

@MainActor @Observable
final class SignetStore {
    var demoOn = false
    var real: SignetInspection?
    var loading = false
    var progress = ""
    var errorText: String?
    private(set) var icsURL: URL?
    private let demo = SignetDemo.make()

    static let importTypes: [UTType] = [UTType.zip] + [UTType(filenameExtension: "ipa")].compactMap { $0 }

    var current: SignetInspection? { demoOn ? demo : real }

    func setDemo(_ on: Bool) {
        demoOn = on
        rebuildExports()
    }

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            errorText = "The file could not be opened: \(e.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            run(url)
        }
    }

    private func run(_ url: URL) {
        loading = true
        errorText = nil
        progress = "Starting"
        let scoped = url.startAccessingSecurityScopedResource()
        SignetProgressBridge.shared.handler = { [weak self] text in self?.progress = text }
        Task {
            let outcome: Result<SignetInspection, Error> = await Task.detached(priority: .userInitiated) { () -> Result<SignetInspection, Error> in
                do { return .success(try SignetInspector.inspect(url: url, progress: { text in
                    Task { @MainActor in SignetProgressBridge.shared.post(text) }
                })) }
                catch { return .failure(error) }
            }.value
            if scoped { url.stopAccessingSecurityScopedResource() }
            loading = false
            switch outcome {
            case .success(let r):
                real = r
                demoOn = false
                Haptics.success()
            case .failure(let e):
                errorText = e.localizedDescription
                Haptics.error()
            }
            rebuildExports()
        }
    }

    func rebuildExports() {
        guard let i = current else { icsURL = nil; return }
        let name = i.isDemo ? "Signet-Demo-profile-expiry.ics" : "Signet-profile-expiry.ics"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try SignetCalendar.ics(for: i).write(to: url, atomically: true, encoding: .utf8)
            icsURL = url
        } catch {
            icsURL = nil
        }
    }
}

/// Lets the background inspector report progress to the main-actor store without capturing it across threads.
@MainActor final class SignetProgressBridge {
    static let shared = SignetProgressBridge()
    var handler: ((String) -> Void)?
    func post(_ text: String) { handler?(text) }
}

// MARK: - Shared small views

struct SignetDemoTag: View {
    var body: some View { Tag(style: .neutral, text: "Demo") }
}

struct SignetExpiryTag: View {
    let days: Int?
    var body: some View {
        switch SignetExpiryTier(daysLeft: days) {
        case .valid: Tag(style: .reversible, text: "Valid")
        case .caution: Tag(style: .caution, text: "Caution")
        case .soon: Tag(style: .experimental, text: "Expiring soon")
        case .expired: Tag(style: .experimental, text: "Expired")
        case .none: Tag(style: .unknown, text: "No profile")
        }
    }
}

func signetDaysText(_ days: Int?) -> String {
    guard let d = days else { return "Not available" }
    if d < 0 { return "\(-d) day\(d == -1 ? "" : "s") ago" }
    if d == 0 { return "today" }
    return "\(d) day\(d == 1 ? "" : "s") left"
}

func signetEvidenceTag(_ e: Evidence) -> Tag {
    switch e {
    case .observed: return Tag(style: .observed)
    case .inferred(let p): return Tag(style: .inferred(p))
    case .unknown: return Tag(style: .unknown)
    }
}

// MARK: - Root

struct SignetRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @State private var store = SignetStore()
    @State private var showImporter = false

    var body: some View {
        List {
            sourceSection
            if store.loading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inspecting").foregroundStyle(t.ink)
                            Text(store.progress).font(.system(size: 13)).foregroundStyle(t.ink2)
                        }
                    }
                }.rowCard()
            } else if let err = store.errorText {
                Section("Problem") {
                    Label(err, systemImage: "xmark.octagon").foregroundStyle(t.ink)
                    Button("Choose another file") { showImporter = true }
                }.rowCard()
            }
            if let i = store.current {
                SignetSummarySection(inspection: i)
                targetsSection(i)
                toolsSection(i)
                if !i.notes.isEmpty {
                    Section("Notes") {
                        ForEach(i.notes, id: \.self) { n in
                            Text(n).font(.system(size: 13.5)).foregroundStyle(t.ink2)
                        }
                    }.rowCard()
                }
            } else if !store.loading && store.errorText == nil {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No file inspected").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                        Text("Choose an .ipa, or a zipped .app, to read its bundle IDs, provisioning profiles and entitlements. Everything is read on this device and nothing is uploaded. To look around without a file, switch on Demo.")
                            .font(.system(size: 13.5)).foregroundStyle(t.ink2)
                    }.padding(.vertical, 4)
                }.rowCard()
            }
        }
        .themedList()
        .navigationTitle("Signet")
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-uiDemo") { store.setDemo(true) } }
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: SignetStore.importTypes, allowsMultipleSelection: false) { result in
            store.handleImport(result)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button { } label: {
                    Text("Signing arrives in a later slice (needs your developer account or certificate).")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
                .padding(.horizontal, 20).padding(.vertical, 10)
            }
            .background(.bar)
        }
    }

    private var sourceSection: some View {
        Section {
            Toggle(isOn: Binding(get: { store.demoOn }, set: { store.setDemo($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) { Text("Demo"); SignetDemoTag() }
                    Text("Shows a made-up app with three extensions. It is not read from a file.")
                        .font(.system(size: 12.5)).foregroundStyle(t.ink2)
                }
            }
            Button { showImporter = true } label: {
                Label(store.real == nil ? "Choose .ipa file" : "Choose another file", systemImage: "doc.zipper")
            }
            .disabled(store.loading)
        } header: {
            Text("Source")
        } footer: {
            Text("No Apple account is needed. The file is read in place and never copied or uploaded.")
        }
        .rowCard()
    }

    private func targetsSection(_ i: SignetInspection) -> some View {
        Section {
            ForEach(i.targets) { tg in
                NavigationLink {
                    SignetTargetDetailView(inspection: i, targetID: tg.id)
                } label: {
                    SignetTargetRow(inspection: i, target: tg)
                }
            }
        } header: {
            Text("Targets (\(i.targets.count))")
        } footer: {
            Text("Expiry tags: more than 30 days is Valid, 7 to 30 is Caution, under 7 or past is Expiring soon or Expired.")
        }
        .rowCard()
    }

    private func toolsSection(_ i: SignetInspection) -> some View {
        Section("Compare and export") {
            NavigationLink { SignetMatrixView(inspection: i) } label: {
                Label("Entitlement matrix", systemImage: "tablecells")
            }
            NavigationLink { SignetDiffView(inspection: i) } label: {
                Label("Requested vs allowed", systemImage: "plusminus")
            }
            NavigationLink { SignetExpiryView(inspection: i, icsURL: store.icsURL) } label: {
                Label("Profile expiry", systemImage: "calendar.badge.clock")
            }
            NavigationLink { SignetReceiptView(inspection: i) } label: {
                Label("Build receipt", systemImage: "doc.plaintext")
            }
        }.rowCard()
    }
}

// MARK: - Summary

struct SignetSummarySection: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection

    var body: some View {
        let a = inspection.app
        Section {
            if inspection.isDemo { HStack { Text("Data"); Spacer(); SignetDemoTag() } }
            fact("Name", a.name)
            fact("Bundle ID", a.bundleID, mono: true)
            fact("Version", "\(a.version ?? "Not available") (\(a.build ?? "Not available"))")
            fact("Minimum iOS", a.minimumOS ?? "Not available")
            fact("Devices", a.deviceFamilies.isEmpty ? "Not available" : a.deviceFamilies.joined(separator: ", "))
            fact("URL schemes", a.urlSchemes.isEmpty ? "None" : a.urlSchemes.joined(separator: ", "), mono: true)
            fact("Background modes", a.backgroundModes.isEmpty ? "None" : a.backgroundModes.joined(separator: ", "), mono: true)
            fact("Usage descriptions", a.usageDescriptionKeys.isEmpty ? "None" : a.usageDescriptionKeys.joined(separator: ", "), mono: true)
            fact("Frameworks", inspection.frameworks.isEmpty ? "None listed" : inspection.frameworks.joined(separator: ", "))
            fact("File", "\(inspection.fileName), \(ByteCountFormatter.string(fromByteCount: inspection.fileSize, countStyle: .file))")
            HStack {
                Text("Binary entitlements").foregroundStyle(t.ink)
                Spacer(minLength: 8)
                Text("Binary entitlements not read").font(.system(size: 13)).foregroundStyle(t.ink2).multilineTextAlignment(.trailing)
                Tag(style: .unknown)
            }
        } header: {
            Text("App")
        }
        .rowCard()
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).foregroundStyle(t.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(mono ? .system(size: 13, design: .monospaced) : .system(size: 15))
                .foregroundStyle(t.ink2).multilineTextAlignment(.trailing)
            Tag(style: .observed)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Target row and detail

struct SignetTargetRow: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection
    let target: SignetTarget

    var body: some View {
        let days = target.profile?.daysLeft()
        let problems = inspection.checks(for: target).filter { $0.status == .fail }.count
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(target.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                Tag(style: .neutral, text: target.kind.rawValue)
                if target.isDemo { SignetDemoTag() }
            }
            Text(target.bundleID).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(t.ink2)
            HStack(spacing: 8) {
                Text(target.profile?.name ?? "No profile").font(.system(size: 13.5)).foregroundStyle(t.ink2)
                SignetExpiryTag(days: days)
                Text(signetDaysText(days)).font(.system(size: 13)).foregroundStyle(t.ink2)
            }
            if problems > 0 {
                Text("\(problems) problem\(problems == 1 ? "" : "s") found").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.ink)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

struct SignetTargetDetailView: View {
    @Environment(\.theme) private var t
    let inspection: SignetInspection
    let targetID: String

    var body: some View {
        if let target = inspection.targets.first(where: { $0.id == targetID }) {
            List {
                Section("Checks") {
                    ForEach(inspection.checks(for: target)) { c in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: c.status.symbol).foregroundStyle(t.ink2).frame(width: 22).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.title).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(t.ink)
                                Text(c.detail).font(.system(size: 13.5)).foregroundStyle(t.ink2)
                                HStack(spacing: 6) {
                                    Tag(style: .neutral, text: c.status.word)
                                    signetEvidenceTag(c.evidence)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }.rowCard()

                Section("Bundle") {
                    row("Bundle ID", target.bundleID, mono: true)
                    row("Path", target.path, mono: true)
                    if let ep = target.extensionPoint { row("Extension point", ep, mono: true) }
                    row("Code signature folder", target.hasCodeSignature ? "Present" : "Absent")
                    row("Privacy manifest", target.hasPrivacyManifest ? "Present" : "Absent")
                }.rowCard()

                if let p = target.profile {
                    Section("Profile") {
                        row("Name", p.name)
                        row("Type (inferred)", p.kind.rawValue)
                        row("Team", p.teamName ?? "Not available")
                        row("Team ID", p.teamIdentifier ?? "Not available", mono: true)
                        row("App ID name", p.appIDName ?? "Not available")
                        row("App ID pattern", p.appIDPattern ?? "Not available", mono: true)
                        row("Created", p.creationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not available")
                        row("Expires", p.expirationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not available")
                        row("Devices", p.provisionsAllDevices ? "All devices" : (p.deviceCount.map { "\($0) devices" } ?? "No device list"))
                        row("get-task-allow", p.getTaskAllow.map { $0 ? "true" : "false" } ?? "Not set")
                        row("aps-environment", p.apsEnvironment ?? "Not set")
                        row("Certificates", "\(p.certificateCount)")
                    }.rowCard()

                    Section {
                        let keys = p.entitlements.keys.sorted()
                        ForEach(keys, id: \.self) { k in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(t.ink)
                                Text(p.entitlements[k] ?? "").font(.system(size: 12.5, design: .monospaced)).foregroundStyle(t.ink2)
                            }
                        }
                        if keys.isEmpty { Text("The profile lists no entitlements.").foregroundStyle(t.ink2) }
                    } header: {
                        Text("Entitlements allowed by the profile")
                    } footer: {
                        Text("Binary entitlements not read. This is what the profile allows, not what the binary requests.")
                    }.rowCard()
                } else {
                    Section("Profile") {
                        Text("No embedded.mobileprovision in this bundle.").foregroundStyle(t.ink2)
                    }.rowCard()
                }
            }
            .themedList()
            .navigationTitle(target.displayName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("This target is no longer available.").foregroundStyle(t.ink2)
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).foregroundStyle(t.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(mono ? .system(size: 12.5, design: .monospaced) : .system(size: 15))
                .foregroundStyle(t.ink2).multilineTextAlignment(.trailing)
            Tag(style: .observed)
        }
        .accessibilityElement(children: .combine)
    }
}
