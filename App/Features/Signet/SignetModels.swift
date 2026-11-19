import Foundation

// MARK: - Profile

/// What we read from an embedded.mobileprovision. Certificates, device identifiers and key material are
/// deliberately NOT stored: only counts are kept.
struct SignetProfile: Hashable, Sendable {
    var name: String
    var teamName: String?
    var teamIdentifier: String?
    var appIDName: String?
    var applicationIdentifier: String?      // entitlement "application-identifier", e.g. TEAMID.com.example.app
    var creationDate: Date?
    var expirationDate: Date?
    var deviceCount: Int?                   // count only; UDIDs are never kept
    var provisionsAllDevices: Bool
    var entitlements: [String: String]      // flattened for display
    var getTaskAllow: Bool?
    var apsEnvironment: String?
    var certificateCount: Int               // count only
    var isDemo = false

    enum Kind: String { case development = "Development", adHoc = "Ad hoc", enterprise = "Enterprise", store = "App Store" }

    /// Inferred from the profile contents; Apple does not label the type in the file.
    var kind: Kind {
        if provisionsAllDevices { return .enterprise }
        if let n = deviceCount, n > 0 { return getTaskAllow == true ? .development : .adHoc }
        return .store
    }
    var isDistribution: Bool { kind != .development }

    func daysLeft(now: Date = Date()) -> Int? {
        guard let e = expirationDate else { return nil }
        return Int((e.timeIntervalSince(now) / 86_400).rounded(.down))
    }

    /// The App ID pattern with the team prefix removed, e.g. "com.example.app" or "com.example.*" or "*".
    var appIDPattern: String? {
        guard let full = applicationIdentifier else { return nil }
        if let team = teamIdentifier, full.hasPrefix(team + ".") { return String(full.dropFirst(team.count + 1)) }
        if let dot = full.firstIndex(of: ".") { return String(full[full.index(after: dot)...]) }
        return full
    }

    /// nil when the profile has no application-identifier to compare against.
    func matches(bundleID: String) -> Bool? {
        guard let p = appIDPattern else { return nil }
        if p == "*" { return true }
        if p.hasSuffix("*") { return bundleID.hasPrefix(String(p.dropLast())) }
        return p == bundleID
    }

    func has(_ key: String) -> Bool { entitlements[key] != nil }
}

enum SignetExpiryTier: Equatable {
    case valid, caution, soon, expired, none

    init(daysLeft: Int?) {
        guard let d = daysLeft else { self = .none; return }
        if d < 0 { self = .expired } else if d < 7 { self = .soon } else if d <= 30 { self = .caution } else { self = .valid }
    }
    var label: String {
        switch self {
        case .valid: return "Valid"
        case .caution: return "Caution"
        case .soon: return "Expires within 7 days"
        case .expired: return "Expired"
        case .none: return "No profile"
        }
    }
}

// MARK: - Targets

struct SignetTarget: Identifiable, Hashable, Sendable {
    enum Kind: String { case app = "App", appex = "Extension" }
    var id: String { path }
    var kind: Kind
    var path: String                        // bundle directory inside the archive
    var bundleID: String
    var displayName: String
    var extensionPoint: String?
    var profile: SignetProfile?
    var hasCodeSignature: Bool
    var hasPrivacyManifest: Bool
    var binary: SignetBinaryEvidence = .unavailable
    var isDemo = false

    var shortName: String {
        if kind == .app { return "App" }
        let last = bundleID.split(separator: ".").last.map(String.init) ?? displayName
        return last
    }
}

struct SignetAppInfo: Hashable, Sendable {
    var bundleID: String
    var name: String
    var version: String?
    var build: String?
    var minimumOS: String?
    var deviceFamilies: [String]
    var urlSchemes: [String]
    var backgroundModes: [String]
    var usageDescriptionKeys: [String]
}

struct SignetInspection: Sendable {
    var fileName: String
    var fileSize: Int64
    var sha256: String?
    var app: SignetAppInfo
    var targets: [SignetTarget]
    var frameworks: [String]
    var privacyTrackingDeclared: Bool?
    var notes: [String]
    var isDemo: Bool
    var inspectedAt = Date()

    var appTarget: SignetTarget? { targets.first { $0.kind == .app } }

    /// Every distinct profile with the targets that use it.
    var profileUsage: [(profile: SignetProfile, targets: [SignetTarget])] {
        var order: [String] = []
        var map: [String: (SignetProfile, [SignetTarget])] = [:]
        for t in targets {
            guard let p = t.profile else { continue }
            let key = p.name + "|" + (p.expirationDate.map { String($0.timeIntervalSince1970) } ?? "-")
            if map[key] == nil { order.append(key); map[key] = (p, [t]) } else { map[key]!.1.append(t) }
        }
        return order.compactMap { k in map[k].map { (profile: $0.0, targets: $0.1) } }
    }
}

// MARK: - Expectations (inferred, not read from the binary)

enum SignetKeys {
    static let appGroups = "com.apple.security.application-groups"
    static let networkExtension = "com.apple.developer.networking.networkextension"
    static let autofillProvider = "com.apple.developer.authentication-services.autofill-credential-provider"
    static let aps = "aps-environment"
    static let getTaskAllow = "get-task-allow"
    /// Present in every profile; hidden from the matrix and diff to keep them readable.
    static let baseline: Set<String> = ["application-identifier", "com.apple.developer.team-identifier", "keychain-access-groups", "beta-reports-active"]
}

extension SignetInspection {
    /// Entitlement keys we expect the target to need. Binary entitlements are not read in this slice,
    /// so this is reasoning from the extension point, Info.plist and the other targets (Inferred).
    func expectedEntitlements(for target: SignetTarget) -> [String] {
        if target.binary.state == .xml { return target.binary.values.keys.sorted() }
        var keys: Set<String> = []
        if let ep = target.extensionPoint {
            if ep.hasPrefix("com.apple.networkextension.") { keys.insert(SignetKeys.networkExtension) }
            if ep.hasPrefix("com.apple.authentication-services-credential-provider") { keys.insert(SignetKeys.autofillProvider) }
        }
        if target.kind == .app, app.backgroundModes.contains("remote-notification") { keys.insert(SignetKeys.aps) }
        // App Groups: if any target has them, app and extensions are expected to share them.
        if targets.contains(where: { $0.profile?.has(SignetKeys.appGroups) == true }) { keys.insert(SignetKeys.appGroups) }
        return keys.sorted()
    }

    /// Token expected inside a Network Extension entitlement value for this extension point.
    static func networkExtensionToken(for extensionPoint: String?) -> String? {
        guard let ep = extensionPoint else { return nil }
        if ep.hasSuffix("packet-tunnel") { return "packet-tunnel-provider" }
        if ep.hasSuffix("app-proxy") { return "app-proxy-provider" }
        if ep.hasSuffix("filter-data") || ep.hasSuffix("filter-control") { return "content-filter-provider" }
        if ep.hasSuffix("dns-proxy") { return "dns-proxy" }
        return nil
    }
}

// MARK: - Checks

enum SignetCheckStatus {
    case pass, warn, fail, note
    var symbol: String {
        switch self { case .pass: return "checkmark.circle"; case .warn: return "exclamationmark.triangle"; case .fail: return "xmark.octagon"; case .note: return "info.circle" }
    }
    var word: String {
        switch self { case .pass: return "Pass"; case .warn: return "Check"; case .fail: return "Problem"; case .note: return "Note" }
    }
}

struct SignetCheck: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let detail: String
    let status: SignetCheckStatus
    let evidence: Evidence
}

extension SignetInspection {
    func checks(for target: SignetTarget, now: Date = Date()) -> [SignetCheck] {
        var out: [SignetCheck] = []
        let p = target.profile

        // Signature state
        if target.hasCodeSignature {
            out.append(SignetCheck(title: "Code signature folder", detail: "_CodeSignature/CodeResources is present. The signature itself is not verified here.", status: .pass, evidence: .observed))
        } else {
            out.append(SignetCheck(title: "No resource seal found", detail: "No _CodeSignature/CodeResources entry. This alone does not determine whether the executable is signed.", status: .note, evidence: .observed))
        }

        // Own profile
        if target.kind == .appex {
            if p == nil {
                out.append(SignetCheck(title: "Extension has its own profile", detail: "No embedded.mobileprovision in this extension. A signed extension needs its own provisioning profile.", status: target.hasCodeSignature ? .fail : .note, evidence: .observed))
            } else {
                out.append(SignetCheck(title: "Extension has its own profile", detail: "embedded.mobileprovision found: \(p!.name).", status: .pass, evidence: .observed))
            }
        } else if p == nil {
            out.append(SignetCheck(title: "Provisioning profile", detail: "No embedded.mobileprovision in the app bundle.", status: target.hasCodeSignature ? .fail : .note, evidence: .observed))
        }

        if let p {
            // Bundle ID vs App ID
            switch p.matches(bundleID: target.bundleID) {
            case .some(true):
                out.append(SignetCheck(title: "Bundle ID matches profile App ID", detail: "\(target.bundleID) fits the pattern \(p.appIDPattern ?? "?").", status: .pass, evidence: .observed))
            case .some(false):
                out.append(SignetCheck(title: "Bundle ID matches profile App ID", detail: "\(target.bundleID) does not fit the pattern \(p.appIDPattern ?? "?").", status: .fail, evidence: .observed))
            case .none:
                out.append(SignetCheck(title: "Bundle ID matches profile App ID", detail: "The profile has no application-identifier to compare.", status: .note, evidence: .unknown))
            }

            // Expiry
            if let d = p.daysLeft(now: now) {
                let text = d < 0 ? "Expired \(-d) day\(d == -1 ? "" : "s") ago." : "\(d) day\(d == 1 ? "" : "s") left."
                out.append(SignetCheck(title: "Profile not expired", detail: text, status: d < 0 ? .fail : (d <= 30 ? .warn : .pass), evidence: .observed))
            } else {
                out.append(SignetCheck(title: "Profile not expired", detail: "No ExpirationDate in the profile.", status: .note, evidence: .unknown))
            }

            // Entitlements vs expected
            let expected = expectedEntitlements(for: target)
            let missing = expected.filter { !p.has($0) }
            if expected.isEmpty {
                out.append(SignetCheck(title: "Profile covers expected entitlements", detail: "No special entitlements expected for this target.", status: .pass, evidence: .inferred(60)))
            } else if missing.isEmpty {
                var detail = "Profile includes \(expected.joined(separator: ", "))."
                var status = SignetCheckStatus.pass
                if let token = Self.networkExtensionToken(for: target.extensionPoint), let v = p.entitlements[SignetKeys.networkExtension], !v.contains(token) {
                    detail = "Network Extension entitlement is present but its value (\(v)) does not list \(token)."
                    status = .warn
                }
                out.append(SignetCheck(title: "Profile covers expected entitlements", detail: detail, status: status, evidence: .inferred(70)))
            } else {
                out.append(SignetCheck(title: "Profile covers expected entitlements", detail: "Missing from the profile: \(missing.joined(separator: ", ")).", status: .fail, evidence: .inferred(80)))
            }

            // get-task-allow on distribution
            if p.getTaskAllow == true && p.isDistribution {
                out.append(SignetCheck(title: "get-task-allow on a distribution profile", detail: "get-task-allow is true although the profile looks like \(p.kind.rawValue). Distribution builds normally have it false.", status: .warn, evidence: .inferred(70)))
            } else if let g = p.getTaskAllow {
                out.append(SignetCheck(title: "get-task-allow", detail: "\(g ? "true" : "false") on a \(p.kind.rawValue) profile. This is expected.", status: .pass, evidence: .inferred(70)))
            }
        }

        // App Groups across app and appex
        let groupHolders = targets.filter { $0.profile?.has(SignetKeys.appGroups) == true }
        if !groupHolders.isEmpty && groupHolders.count < targets.filter({ $0.profile != nil }).count {
            if target.profile?.has(SignetKeys.appGroups) != true {
                out.append(SignetCheck(title: "App Groups present in app and extension", detail: "Other targets have App Groups but this one does not, so shared containers will not work.", status: .fail, evidence: .inferred(75)))
            } else {
                out.append(SignetCheck(title: "App Groups present in app and extension", detail: "Present here; at least one other target is missing it.", status: .warn, evidence: .inferred(75)))
            }
        } else if !groupHolders.isEmpty {
            out.append(SignetCheck(title: "App Groups present in app and extension", detail: "Every target with a profile lists App Groups.", status: .pass, evidence: .observed))
        }

        // Privacy manifest
        if target.hasPrivacyManifest {
            out.append(SignetCheck(title: "Privacy manifest", detail: "PrivacyInfo.xcprivacy is present in this bundle.", status: .pass, evidence: .observed))
        } else {
            out.append(SignetCheck(title: "Privacy manifest", detail: "No PrivacyInfo.xcprivacy in this bundle. App Store submissions may need one if required-reason APIs are used.", status: .note, evidence: .observed))
        }

        out.append(SignetCheck(title: "Binary entitlements", detail: target.binary.summary + ". Signature validity is not checked.", status: .note, evidence: target.binary.observed ? .observed : .unknown))
        return out
    }
}

// MARK: - Entitlement matrix and diff

enum SignetCell { case present, absent, missing
    var symbol: String { switch self { case .present: return "✓"; case .absent: return "–"; case .missing: return "✗" } }
    var spoken: String { switch self { case .present: return "in profile"; case .absent: return "not in profile, not expected"; case .missing: return "expected but missing from profile" } }
}

struct SignetDiffLine: Identifiable, Hashable {
    enum Kind { case missing, extra, same }
    var id: String { key }
    let kind: Kind
    let key: String
    let note: String
    var sign: String { switch kind { case .missing: return "−"; case .extra: return "+"; case .same: return " " } }
}

extension SignetInspection {
    /// Union of entitlement keys across profiles and expectations, minus the baseline keys every profile has.
    var matrixKeys: [String] {
        var keys: Set<String> = []
        for t in targets {
            for k in (t.profile?.entitlements.keys.map { $0 } ?? []) where !SignetKeys.baseline.contains(k) { keys.insert(k) }
            for k in expectedEntitlements(for: t) { keys.insert(k) }
        }
        return keys.sorted()
    }

    func cell(key: String, target: SignetTarget) -> SignetCell {
        if target.profile?.has(key) == true { return .present }
        return expectedEntitlements(for: target).contains(key) ? .missing : .absent
    }

    /// "Requested by target" (inferred) against "allowed by profile".
    /// − = expected but not in the profile. + = in the profile but not expected. Blank = both agree.
    func diff(for target: SignetTarget) -> [SignetDiffLine] {
        let expected = Set(expectedEntitlements(for: target))
        let allowed = target.profile?.entitlements ?? [:]
        var lines: [SignetDiffLine] = []
        for k in expected.sorted() {
            if let v = allowed[k] { lines.append(SignetDiffLine(kind: .same, key: k, note: v)) }
            else { lines.append(SignetDiffLine(kind: .missing, key: k, note: "expected, not in profile")) }
        }
        for k in allowed.keys.sorted() where !expected.contains(k) && !SignetKeys.baseline.contains(k) {
            lines.append(SignetDiffLine(kind: .extra, key: k, note: allowed[k] ?? ""))
        }
        return lines
    }
}

// MARK: - Calendar export (.ics)

enum SignetCalendar {
    /// One event per distinct profile at its expiry time, with reminders 14, 3 and 0 days before.
    static func ics(for inspection: SignetInspection, now: Date = Date()) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Assay//Signet//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH"
        ]
        let stamp = utc(now)
        for (i, u) in inspection.profileUsage.enumerated() {
            guard let exp = u.profile.expirationDate else { continue }
            let names = u.targets.map { $0.bundleID }.joined(separator: ", ")
            let title = "Provisioning profile expires: \(u.profile.name)"
            let desc = "Profile \(u.profile.name) used by \(names)." + (inspection.isDemo ? " Demo data." : "")
            lines += [
                "BEGIN:VEVENT",
                "UID:signet-\(i)-\(Int(exp.timeIntervalSince1970))@assay.local",
                "DTSTAMP:\(stamp)",
                "DTSTART:\(utc(exp))",
                "DTEND:\(utc(exp.addingTimeInterval(3600)))",
                "SUMMARY:\(escape(title))",
                "DESCRIPTION:\(escape(desc))"
            ]
            for (trigger, label) in [("-P14D", "14 days"), ("-P3D", "3 days"), ("PT0S", "now")] {
                lines += [
                    "BEGIN:VALARM", "ACTION:DISPLAY",
                    "DESCRIPTION:\(escape(label == "now" ? "Profile expires now: \(u.profile.name)" : "Profile expires in \(label): \(u.profile.name)"))",
                    "TRIGGER:\(trigger)", "END:VALARM"
                ]
            }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    private static func utc(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: d)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// RFC 5545 folding at 73 characters (conservative for UTF-8).
    private static func fold(_ line: String) -> String {
        let chars = Array(line)
        if chars.count <= 73 { return line }
        var out = ""
        var i = 0
        while i < chars.count {
            let end = min(i + (i == 0 ? 73 : 72), chars.count)
            out += (i == 0 ? "" : "\r\n ") + String(chars[i..<end])
            i = end
        }
        return out
    }
}

// MARK: - Build receipt (plain text)

enum SignetReceipt {
    /// Never contains certificates, device identifiers or key material. Device counts only.
    static func text(for i: SignetInspection, now: Date = Date()) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        var s: [String] = []
        s.append("Signet build receipt")
        if i.isDemo { s.append("DEMO DATA — not from a real file") }
        s.append("Generated: \(df.string(from: now))")
        s.append("")
        s.append("App ID: \(i.app.bundleID)")
        s.append("Name: \(i.app.name)")
        s.append("Version: \(i.app.version ?? "Not available") (build \(i.app.build ?? "Not available"))")
        s.append("Minimum iOS: \(i.app.minimumOS ?? "Not available")")
        s.append("File: \(i.fileName) (\(ByteCountFormatter.string(fromByteCount: i.fileSize, countStyle: .file)))")
        s.append("SHA-256: \(i.sha256 ?? "Not computed (demo)")")
        s.append("")
        s.append("Targets (\(i.targets.count)):")
        for t in i.targets {
            s.append("- \(t.kind.rawValue): \(t.bundleID)")
            s.append("  Signed folder present: \(t.hasCodeSignature ? "yes" : "no")")
            if let p = t.profile {
                let days = p.daysLeft(now: now).map { "\($0) days left" } ?? "no expiry"
                let exp = p.expirationDate.map { df.string(from: $0) } ?? "Not available"
                let dev = p.provisionsAllDevices ? "all devices" : (p.deviceCount.map { "\($0) devices" } ?? "no device list")
                s.append("  Profile: \(p.name) (\(p.kind.rawValue))")
                s.append("  Expires: \(exp) — \(days)")
                s.append("  Devices: \(dev)")
            } else {
                s.append("  Profile: none")
            }
        }
        s.append("")
        for target in i.targets { s.append("  \(target.shortName): \(target.binary.summary)") }; s.append("Signature and installability not verified.")
        return s.joined(separator: "\n") + "\n"
    }
}
