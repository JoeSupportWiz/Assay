import Foundation

// MARK: - Service types

/// The fixed list of Bonjour service types Assay browses. Nothing outside this list is ever queried.
struct NetServiceKind: Identifiable {
    let type: String          // e.g. "_http._tcp"
    let title: String         // plain label
    let tlsCapable: Bool      // offers the certificate check from the device screen
    var id: String { type }

    static let all: [NetServiceKind] = [
        NetServiceKind(type: "_http._tcp", title: "Web (HTTP)", tlsCapable: false),
        NetServiceKind(type: "_https._tcp", title: "Web (HTTPS)", tlsCapable: true),
        NetServiceKind(type: "_ssh._tcp", title: "SSH", tlsCapable: false),
        NetServiceKind(type: "_smb._tcp", title: "File sharing (SMB)", tlsCapable: false),
        NetServiceKind(type: "_airplay._tcp", title: "AirPlay", tlsCapable: false),
        NetServiceKind(type: "_raop._tcp", title: "AirPlay audio", tlsCapable: false),
        NetServiceKind(type: "_hap._tcp", title: "HomeKit accessory", tlsCapable: false),
        NetServiceKind(type: "_ipp._tcp", title: "Printing (IPP)", tlsCapable: false),
        NetServiceKind(type: "_printer._tcp", title: "Printing (LPD)", tlsCapable: false),
        NetServiceKind(type: "_workstation._tcp", title: "Workstation", tlsCapable: false),
        NetServiceKind(type: "_companion-link._tcp", title: "Apple companion link", tlsCapable: false),
        NetServiceKind(type: "_device-info._tcp", title: "Device info", tlsCapable: false),
        NetServiceKind(type: "_googlecast._tcp", title: "Google Cast", tlsCapable: false),
        NetServiceKind(type: "_spotify-connect._tcp", title: "Spotify Connect", tlsCapable: false)
    ]

    static func kind(for type: String) -> NetServiceKind? {
        let n = normaliseType(type)
        return all.first { $0.type == n }
    }

    static func title(for type: String) -> String {
        kind(for: type)?.title ?? type
    }

    /// "_http._tcp." -> "_http._tcp"
    static func normaliseType(_ s: String) -> String {
        s.hasSuffix(".") ? String(s.dropLast()) : s
    }
}

// MARK: - Discovered service and grouped device

struct NetFoundService: Identifiable {
    enum Resolve: Equatable {
        case idle, resolving, resolved
        case failed(String)
    }

    let id: String
    var name: String
    var type: String
    var domain: String
    var interface: String
    var txtKeys: [String]
    var host: String?
    var port: UInt16?
    var resolve: Resolve = .idle
    var firstSeen: Date
    var lastSeen: Date
    var isPresent: Bool = true
    var isDemo: Bool = false
    var demoCert: NetCertInfo? = nil
    var demoLatency: [Double?]? = nil

    var kind: NetServiceKind? { NetServiceKind.kind(for: type) }
    var hostPortKey: String? {
        guard let h = host, let p = port else { return nil }
        return "\(h):\(p)"
    }
}

struct NetDevice: Identifiable {
    let name: String
    var services: [NetFoundService]
    var id: String { name }
    var count: Int { services.count }
    var lastSeen: Date { services.map(\.lastSeen).max() ?? .distantPast }
    var isPresent: Bool { services.contains { $0.isPresent } }
    var isDemo: Bool { services.contains { $0.isDemo } }
}

// MARK: - Latency and certificate results

struct NetLatencyResult {
    let samples: [Double?]    // milliseconds; nil = timed out or refused
    let date: Date
    var isDemo: Bool = false

    var ok: [Double] { samples.compactMap { $0 } }
    var minMs: Double? { ok.min() }
    var maxMs: Double? { ok.max() }
    var avgMs: Double? { ok.isEmpty ? nil : ok.reduce(0, +) / Double(ok.count) }
    var lost: Int { samples.count - ok.count }
    var lossPercent: Int { samples.isEmpty ? 0 : Int((Double(lost) / Double(samples.count) * 100).rounded()) }
}

struct NetCertInfo {
    var subject: String
    var issuer: String
    var notBefore: Date?
    var notAfter: Date?
    var keyType: String        // "RSA", "Elliptic curve", "Not available"
    var keyBits: Int?
    var isRSA: Bool
    var selfSigned: Bool
    var trustedByDevice: Bool?
    var isDemo: Bool = false

    func daysLeft(now: Date = Date()) -> Int? {
        guard let end = notAfter else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: end).day
    }
    func isExpired(now: Date = Date()) -> Bool {
        guard let end = notAfter else { return false }
        return end < now
    }
    func notYetValid(now: Date = Date()) -> Bool {
        guard let start = notBefore else { return false }
        return start > now
    }
    var isWeak: Bool {
        guard isRSA, let bits = keyBits else { return false }
        return bits < 2048
    }
}

struct NetCertResult {
    var info: NetCertInfo?
    var error: String?
    var date: Date
}

// MARK: - Address policy (private and local addresses only)

enum NetAddressPolicy {
    struct Verdict {
        /// Exactly the host to give the transport. Never probe the unchecked input string.
        let host: String?
        let reason: String
        var allowed: Bool { host != nil }
    }

    static let refusal = "Use a private IPv4, link-local or unique-local IPv6 address, or a .local host name. Public, shared and unrecognised addresses are not tested."

    static func check(_ raw: String) -> Verdict {
        let host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { return Verdict(host: nil, reason: "Enter a host name or IP address.") }
        // Accept the usual bracket notation for a manually entered IPv6 literal only.
        if host.hasPrefix("["), host.hasSuffix("]"), host.contains(":") {
            return checkDiscovered(String(host.dropFirst().dropLast()))
        }
        return checkDiscovered(host)
    }

    /// An advertisement is not a grant of trust. A resolved bare host has the same allowlist as a typed host.
    static func checkDiscovered(_ host: String) -> Verdict {
        switch LocalNetworkHost.classify(host) {
        case .privateIPv4: return Verdict(host: host, reason: "Private IPv4 address.")
        case .linkLocal: return Verdict(host: host, reason: "Link-local address.")
        case .uniqueLocalIPv6: return Verdict(host: host, reason: "Unique local IPv6 address.")
        case .localName: return Verdict(host: host, reason: "Local name (.local).")
        case .loopback: return Verdict(host: nil, reason: "That address points at this device itself, not another device on your network.")
        case .other: return Verdict(host: nil, reason: refusal)
        }
    }
}

// MARK: - Demo data (every value here is simulated and shown with a Demo tag)

enum NetDemo {
    static func make(now: Date = Date()) -> [NetFoundService] {
        let day: TimeInterval = 86_400
        func svc(_ name: String, _ type: String, _ host: String, _ port: UInt16, _ txt: [String], seen: TimeInterval) -> NetFoundService {
            NetFoundService(id: "demo|\(name)|\(type)", name: name, type: type, domain: "local", interface: "en0 · Wi-Fi",
                       txtKeys: txt, host: host, port: port, resolve: .resolved,
                       firstSeen: now.addingTimeInterval(-seen - 600), lastSeen: now.addingTimeInterval(-seen),
                       isPresent: true, isDemo: true)
        }
        var printer = svc("Demo · Office printer", "_ipp._tcp", "192.168.1.20", 631, ["rp", "ty", "adminurl", "pdl"], seen: 30)
        printer.demoLatency = [6.2, 5.8, 7.1, 6.0, 6.4]

        var speaker = svc("Demo · Kitchen speaker", "_airplay._tcp", "192.168.1.31", 7000, ["deviceid", "features", "model"], seen: 75)
        speaker.demoLatency = [11.4, 9.8, 38.5, 10.2, 12.0]

        var cast = svc("Demo · Media box", "_googlecast._tcp", "192.168.1.44", 8009, ["id", "md", "fn", "ve"], seen: 140)
        cast.demoLatency = [14.9, 15.3, 13.7, 16.1, 14.4]

        var nas = svc("Demo · File server", "_https._tcp", "192.168.1.50", 443, ["path"], seen: 12)
        nas.demoLatency = [3.1, 2.9, 3.4, 3.0, 3.2]
        nas.demoCert = NetCertInfo(subject: "demo-fileserver.local", issuer: "Demo Home CA",
                                   notBefore: now.addingTimeInterval(-405 * day), notAfter: now.addingTimeInterval(-40 * day),
                                   keyType: "RSA", keyBits: 2048, isRSA: true, selfSigned: false, trustedByDevice: false, isDemo: true)

        var camera = svc("Demo · Hallway camera", "_https._tcp", "192.168.1.61", 8443, ["model", "fw"], seen: 200)
        camera.demoLatency = [22.0, nil, 24.6, 21.3, 23.8]
        camera.demoCert = NetCertInfo(subject: "demo-camera", issuer: "demo-camera",
                                      notBefore: now.addingTimeInterval(-900 * day), notAfter: now.addingTimeInterval(120 * day),
                                      keyType: "RSA", keyBits: 1024, isRSA: true, selfSigned: true, trustedByDevice: false, isDemo: true)

        var hub = svc("Demo · Home hub", "_https._tcp", "192.168.1.70", 443, ["version", "uuid"], seen: 5)
        hub.demoLatency = [4.4, 4.1, 4.8, 4.2, 4.5]
        hub.demoCert = NetCertInfo(subject: "demo-hub.local", issuer: "Demo Local CA",
                                   notBefore: now.addingTimeInterval(-60 * day), notAfter: now.addingTimeInterval(200 * day),
                                   keyType: "Elliptic curve", keyBits: 256, isRSA: false, selfSigned: false, trustedByDevice: false, isDemo: true)

        return [printer, speaker, cast, nas, camera, hub]
    }
}

// MARK: - Bonjour list for the lead

enum NetBonjourConfig {
    /// Exactly the strings to add to NSBonjourServices (project.yml), alongside any existing entries.
    static var infoPlistServices: [String] { NetServiceKind.all.map(\.type) }
}
