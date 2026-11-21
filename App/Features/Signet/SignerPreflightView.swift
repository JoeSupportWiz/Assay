import SwiftUI
import UniformTypeIdentifiers

private enum PreflightPick { case certificate, profiles }
private typealias ProfileRead = Result<SignerProfileClaims, SignerPreflightError>

// File I/O and parsing run serially off the UI actor. No selected URLs are stored.
private actor PreflightLoader {
    func certificate(_ url: URL) throws -> SignerPublicCertificate { try SignerPreflightReader.certificate(url) }
    func profiles(_ urls: [URL]) throws -> [ProfileRead] {
        try urls.map { url in
            try Task.checkCancellation()
            do { return .success(try SignerPreflightReader.profile(url)) }
            catch { return .failure(error as? SignerPreflightError ?? .file) }
        }
    }
}

struct SignerPreflightView: View {
    @State private var loader = PreflightLoader()
    @State private var pick = PreflightPick.certificate
    @State private var importing = false
    @State private var work: Task<Void, Never>?
    @State private var cert: SignerPublicCertificate?
    @State private var profiles: [ProfileRead] = []
    @State private var draft = ""
    @State private var target: String?
    @State private var notice: String?
    @State private var asOf = Date()

    var body: some View {
        Form {
            Section {
                Text("Compare a public certificate with what provisioning profiles declare. No private key is needed.")
                Button(cert == nil ? "Choose public certificate" : "Replace public certificate") { choose(.certificate) }
                Button(profiles.isEmpty ? "Choose profiles" : "Replace profiles") { choose(.profiles) }
                if work != nil { ProgressView("Reading locally…") }
                if let notice { Text(notice).foregroundStyle(.secondary) }
            } footer: {
                Text("One .cer or certificate-only PEM (64 KiB); up to six .mobileprovision files (2 MiB each). No .p12, keys, or passwords.")
            }
            Section("Target bundle ID") {
                TextField("com.example.app", text: $draft)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                    .onChange(of: draft) { _, _ in target = nil }
                Button("Check target") {
                    asOf = Date()
                    if SignerPreflightRules.bundleID(draft) { target = draft; notice = nil }
                    else { target = nil; notice = "Enter a concrete bundle ID using letters, numbers, hyphens, and nonempty dot-separated components." }
                }.disabled(profiles.isEmpty || work != nil)
                if let target { Text("Checked: \(target)") }
            }
            if let cert {
                Section("Public certificate") {
                    Text("SHA-256 · full DER").font(.caption)
                    Text(cert.digest.map { String(format: "%02x", $0) }.joined()).font(.system(.footnote, design: .monospaced))
                    if let starts = cert.starts {
                        LabeledContent("Not before", value: starts.formatted())
                        Text(asOf < starts ? "Validity period has not started" : "Validity period has started")
                    } else { LabeledContent("Validity start", value: "Unknown") }
                    expiry(cert.expires)
                }
            }
            ForEach(profiles.indices, id: \.self) { i in
                Section("Profile \(i + 1)") {
                    switch profiles[i] {
                    case .failure(let error): Text(error.rawValue); Text("Profile checks: Unknown")
                    case .success(let claims):
                        LabeledContent("Certificate in profile", value: SignerPreflightRules.membership(cert?.digest, in: claims.certificates).rawValue)
                        expiry(claims.expires)
                        LabeledContent("Allowed bundle pattern", value: claims.pattern ?? "Unknown")
                        LabeledContent("Target matches pattern", value: SignerPreflightRules.target(target, allowedBy: claims.pattern).rawValue)
                    }
                }
            }
            Section("Limits of this check") {
                Text("CMS signature and issuer trust: Unknown (not verified). Device eligibility, entitlements and signing identity are not checked.")
                if cert != nil || !profiles.isEmpty { Text("Dates compared at \(asOf.formatted(date: .abbreviated, time: .standard)).") }
                Button("Clear selected data", role: .destructive) { clear() }
            }
        }
        .navigationTitle("Signer preflight")
        .fileImporter(isPresented: $importing, allowedContentTypes: allowedTypes,
                      allowsMultipleSelection: pick == .profiles) { result in
            if case .success(let urls) = result { load(urls) }
            else if case .failure(let error) = result, (error as NSError).code != NSUserCancelledError {
                notice = "File selection could not be opened."
            }
        }
        .onDisappear { clear() }
    }

    @ViewBuilder private func expiry(_ date: Date?) -> some View {
        let status = SignerPreflightRules.expiry(date, asOf: asOf)
        LabeledContent("Expiry", value: status == .yes ? "Not expired" : status == .no ? "Expired" : "Unknown")
        if let date { Text(date.formatted(date: .abbreviated, time: .standard)).font(.footnote) }
    }

    private var allowedTypes: [UTType] {
        (pick == .certificate ? ["cer", "pem"] : ["mobileprovision"]).compactMap { UTType(filenameExtension: $0) }
    }
    private func choose(_ kind: PreflightPick) {
        guard work == nil else { return }
        pick = kind; importing = true
    }
    private func load(_ urls: [URL]) {
        work?.cancel(); work = nil; notice = nil; target = nil
        let kind = pick
        if kind == .certificate { cert = nil } else { profiles = [] }
        guard !urls.isEmpty, urls.count <= (kind == .profiles ? SignerPreflightReader.maxProfiles : 1) else {
            notice = "Selection exceeds the file count limit or is empty."; return
        }
        work = Task { @MainActor in
            defer { if !Task.isCancelled { work = nil } }
            do {
                if kind == .certificate {
                    let value = try await loader.certificate(urls[0]); try Task.checkCancellation(); cert = value
                } else {
                    let values = try await loader.profiles(urls); try Task.checkCancellation(); profiles = values
                }
                asOf = Date()
            } catch {
                if !Task.isCancelled { notice = (error as? SignerPreflightError ?? .file).rawValue }
            }
        }
    }
    private func clear() {
        work?.cancel(); work = nil; cert = nil; profiles = []; draft = ""; target = nil; notice = nil
    }
}
