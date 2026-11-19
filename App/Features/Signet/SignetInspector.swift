import Foundation
import CryptoKit

// MARK: - Provisioning profile parsing

enum SignetProfileParser {
    /// A .mobileprovision is a CMS (PKCS#7) SignedData blob that wraps an XML plist in clear.
    /// We do not verify the CMS signature. We locate the plist by scanning for the bytes "<?xml" and the
    /// last "</plist>", then parse that slice with PropertyListSerialization. This is a pragmatic, documented
    /// shortcut: it reads what the profile claims, it does not prove Apple signed it.
    static func parse(_ blob: Data) -> SignetProfile? {
        guard let start = blob.range(of: Data("<?xml".utf8)),
              let end = blob.range(of: Data("</plist>".utf8), options: .backwards),
              start.lowerBound < end.upperBound else { return nil }
        let xml = blob.subdata(in: start.lowerBound..<end.upperBound)
        guard let obj = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil),
              let d = obj as? [String: Any] else { return nil }

        let ent = d["Entitlements"] as? [String: Any] ?? [:]
        var flat: [String: String] = [:]
        for (k, v) in ent { flat[k] = describe(v) }

        let teams = d["TeamIdentifier"] as? [String]
        let devices = d["ProvisionedDevices"] as? [Any]
        let certs = d["DeveloperCertificates"] as? [Any]

        return SignetProfile(
            name: d["Name"] as? String ?? "Unnamed profile",
            teamName: d["TeamName"] as? String,
            teamIdentifier: teams?.first,
            appIDName: d["AppIDName"] as? String,
            applicationIdentifier: ent["application-identifier"] as? String,
            creationDate: d["CreationDate"] as? Date,
            expirationDate: d["ExpirationDate"] as? Date,
            deviceCount: devices?.count,
            provisionsAllDevices: (d["ProvisionsAllDevices"] as? Bool) ?? false,
            entitlements: flat,
            getTaskAllow: ent["get-task-allow"] as? Bool,
            apsEnvironment: ent["aps-environment"] as? String,
            certificateCount: certs?.count ?? 0)
    }

    private static func describe(_ v: Any) -> String {
        if let b = v as? Bool { return b ? "true" : "false" }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let a = v as? [Any] { return a.map { describe($0) }.joined(separator: ", ") }
        if let d = v as? [String: Any] { return "\(d.count) keys" }
        if v is Data { return "(data)" }
        return String(describing: v)
    }
}

// MARK: - Inspector

enum SignetInspectError: LocalizedError {
    case noApp
    case noInfoPlist(String)
    case badInfoPlist(String)

    var errorDescription: String? {
        switch self {
        case .noApp: return "No Payload/<name>.app/Info.plist was found. This does not look like an .ipa or a zipped .app."
        case .noInfoPlist(let p): return "No Info.plist at \(p)."
        case .badInfoPlist(let p): return "Info.plist at \(p) could not be read as a property list."
        }
    }
}

enum SignetInspector {
    /// Runs on a background thread. Reads only the entries it needs, each capped at 8 MB.
    static func inspect(url: URL, progress: (@Sendable (String) -> Void)? = nil) throws -> SignetInspection {
        progress?("Reading the ZIP index")
        let zip = try SignetZipReader(url: url)
        var notes: [String] = []

        // Locate the app bundle: Payload/X.app/ (ipa) or X.app/ (zipped app).
        let names = zip.entries.map { $0.name }
        let appInfoNames = names.filter { n in
            guard n.hasSuffix(".app/Info.plist") else { return false }
            let parts = n.split(separator: "/")
            return (parts.count == 3 && parts[0] == "Payload") || parts.count == 2
        }.sorted()
        guard let appInfoPath = appInfoNames.first else { throw SignetInspectError.noApp }
        let appDir = String(appInfoPath.dropLast("Info.plist".count))      // ends with "/"
        if appInfoNames.count > 1 { notes.append("More than one .app found; inspecting \(appDir).") }

        // Targets: the app plus every nested .appex (including those inside Watch apps).
        var bundleDirs: [(dir: String, kind: SignetTarget.Kind)] = [(appDir, .app)]
        for n in names where n.hasPrefix(appDir) && n.hasSuffix(".appex/Info.plist") {
            bundleDirs.append((String(n.dropLast("Info.plist".count)), .appex))
        }
        bundleDirs = [bundleDirs[0]] + bundleDirs.dropFirst().sorted { $0.dir < $1.dir }

        var targets: [SignetTarget] = []
        var appInfo: SignetAppInfo?
        var appTracking: Bool?

        for (idx, b) in bundleDirs.enumerated() {
            progress?("Reading \(b.dir)")
            guard let e = zip.entry(named: b.dir + "Info.plist") else { throw SignetInspectError.noInfoPlist(b.dir) }
            let data: Data
            do { data = try zip.extract(e) } catch let err as SignetZipError {
                if b.kind == .app { throw err }
                notes.append("Skipped \(b.dir): \(err.localizedDescription)")
                continue
            }
            guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
                if b.kind == .app { throw SignetInspectError.badInfoPlist(b.dir) }
                notes.append("Skipped \(b.dir): Info.plist unreadable (it may be in an unsupported format).")
                continue
            }

            let bundleID = plist["CFBundleIdentifier"] as? String ?? "Not available"
            let display = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? bundleID
            let ext = (plist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String

            var profile: SignetProfile?
            if let pe = zip.entry(named: b.dir + "embedded.mobileprovision") {
                do {
                    let blob = try zip.extract(pe)
                    profile = SignetProfileParser.parse(blob)
                    if profile == nil { notes.append("Profile in \(b.dir) could not be parsed.") }
                } catch { notes.append("Profile in \(b.dir) skipped: \(error.localizedDescription)") }
            }

            var privacy = false
            if let pe = zip.entry(named: b.dir + "PrivacyInfo.xcprivacy") {
                privacy = true
                if b.kind == .app, let pd = try? zip.extract(pe),
                   let pp = (try? PropertyListSerialization.propertyList(from: pd, options: [], format: nil)) as? [String: Any] {
                    appTracking = pp["NSPrivacyTracking"] as? Bool
                }
            }

            targets.append(SignetTarget(
                kind: b.kind, path: b.dir, bundleID: bundleID, displayName: display, extensionPoint: ext,
                profile: profile, hasCodeSignature: zip.hasEntry(b.dir + "_CodeSignature/CodeResources"),
                hasPrivacyManifest: privacy))

            if idx == 0 {
                let families = (plist["UIDeviceFamily"] as? [Any] ?? []).compactMap { v -> String? in
                    let n = (v as? Int) ?? (v as? NSNumber)?.intValue ?? -1
                    switch n { case 1: return "iPhone"; case 2: return "iPad"; case 3: return "Apple TV"; case 4: return "Apple Watch"; case 7: return "Apple Vision"; default: return nil }
                }
                let schemes = (plist["CFBundleURLTypes"] as? [[String: Any]] ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
                let usage = plist.keys.filter { $0.hasSuffix("UsageDescription") }.sorted()
                appInfo = SignetAppInfo(
                    bundleID: bundleID, name: display,
                    version: plist["CFBundleShortVersionString"] as? String,
                    build: plist["CFBundleVersion"] as? String,
                    minimumOS: plist["MinimumOSVersion"] as? String,
                    deviceFamilies: families, urlSchemes: schemes,
                    backgroundModes: plist["UIBackgroundModes"] as? [String] ?? [],
                    usageDescriptionKeys: usage)
            }
        }
        guard let info = appInfo else { throw SignetInspectError.noApp }

        // Frameworks listing (first level only; no extraction).
        let fwPrefix = appDir + "Frameworks/"
        var fw = Set<String>()
        for n in names where n.hasPrefix(fwPrefix) {
            let rest = n.dropFirst(fwPrefix.count)
            if let first = rest.split(separator: "/").first { fw.insert(String(first)) }
        }

        progress?("Hashing the file")
        var hasher = SHA256()
        try zip.readChunks { hasher.update(data: $0) }
        let hex = hasher.finalize().map { String(format: "%02x", $0) }.joined()

        notes.append("Binary entitlements not read. The profile's allowed entitlements are shown; what the binary requests is Unknown.")
        return SignetInspection(
            fileName: url.lastPathComponent, fileSize: zip.fileSize, sha256: hex, app: info, targets: targets,
            frameworks: fw.sorted(), privacyTrackingDeclared: appTracking, notes: notes, isDemo: false)
    }
}

// MARK: - Demo data (in memory, clearly marked)

enum SignetDemo {
    static func make(now: Date = Date()) -> SignetInspection {
        func days(_ n: Int) -> Date { now.addingTimeInterval(Double(n) * 86_400 + 3_600) }
        let team = "DEMO123456"
        let groups = "group.com.example.notes"

        func profile(_ name: String, id: String, left: Int, devices: Int, ent: [String: String]) -> SignetProfile {
            var e = ent
            e["application-identifier"] = "\(team).\(id)"
            e["com.apple.developer.team-identifier"] = team
            e["get-task-allow"] = "false"
            return SignetProfile(
                name: name, teamName: "Demo Team", teamIdentifier: team, appIDName: name,
                applicationIdentifier: "\(team).\(id)", creationDate: days(left - 365), expirationDate: days(left),
                deviceCount: devices, provisionsAllDevices: false, entitlements: e,
                getTaskAllow: false, apsEnvironment: e["aps-environment"], certificateCount: 1, isDemo: true)
        }

        let app = SignetTarget(
            kind: .app, path: "Payload/Notes.app/", bundleID: "com.example.notes", displayName: "Demo Notes",
            extensionPoint: nil,
            profile: profile("Demo Notes AdHoc", id: "com.example.notes", left: 120, devices: 3, ent: [
                SignetKeys.appGroups: groups, SignetKeys.aps: "production",
                SignetKeys.networkExtension: "packet-tunnel-provider"]),
            hasCodeSignature: true, hasPrivacyManifest: true, isDemo: true)
        let tunnel = SignetTarget(
            kind: .appex, path: "Payload/Notes.app/PlugIns/Tunnel.appex/", bundleID: "com.example.notes.tunnel", displayName: "Demo Tunnel",
            extensionPoint: "com.apple.networkextension.packet-tunnel",
            // Mismatch: the Network Extension entitlement is missing from this profile.
            profile: profile("Demo Tunnel AdHoc", id: "com.example.notes.tunnel", left: 120, devices: 3, ent: [SignetKeys.appGroups: groups]),
            hasCodeSignature: true, hasPrivacyManifest: false, isDemo: true)
        let widget = SignetTarget(
            kind: .appex, path: "Payload/Notes.app/PlugIns/Widget.appex/", bundleID: "com.example.notes.widget", displayName: "Demo Widget",
            extensionPoint: "com.apple.widgetkit-extension",
            profile: profile("Demo Widget AdHoc", id: "com.example.notes.widget", left: 45, devices: 3, ent: [SignetKeys.appGroups: groups]),
            hasCodeSignature: true, hasPrivacyManifest: true, isDemo: true)
        let share = SignetTarget(
            kind: .appex, path: "Payload/Notes.app/PlugIns/Share.appex/", bundleID: "com.example.notes.share", displayName: "Demo Share",
            extensionPoint: "com.apple.share-services",
            // Near expiry: 5 days left.
            profile: profile("Demo Share AdHoc", id: "com.example.notes.share", left: 5, devices: 3, ent: [SignetKeys.appGroups: groups]),
            hasCodeSignature: true, hasPrivacyManifest: true, isDemo: true)

        return SignetInspection(
            fileName: "DemoNotes.ipa", fileSize: 18_400_000, sha256: nil,
            app: SignetAppInfo(bundleID: "com.example.notes", name: "Demo Notes", version: "2.4.0", build: "318", minimumOS: "17.0",
                               deviceFamilies: ["iPhone", "iPad"], urlSchemes: ["demonotes"], backgroundModes: ["remote-notification"],
                               usageDescriptionKeys: ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]),
            targets: [app, tunnel, widget, share],
            frameworks: ["DemoKit.framework", "DemoCrypto.framework"],
            privacyTrackingDeclared: false,
            notes: ["Demo data. Nothing here came from a real file.",
                    "Binary entitlements not read. The profile's allowed entitlements are shown; what the binary requests is Unknown."],
            isDemo: true)
    }
}
