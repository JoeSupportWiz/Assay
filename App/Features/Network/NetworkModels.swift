import Foundation
import Darwin

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
        let allowed: Bool
        let reason: String
    }

    static let refusal = "Assay only tests devices on your own network, so it refuses public addresses. Use a private address (10.x.x.x, 172.16–31.x.x, 192.168.x.x), a link-local address (169.254.x.x or fe80::) or a .local name."

    static func check(_ raw: String) -> Verdict {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("[") && host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        if host.isEmpty { return Verdict(allowed: false, reason: "Enter a host name or IP address.") }
        if host.contains("/") || host.contains(" ") || host.contains("@") {
            return Verdict(allowed: false, reason: "Enter only the host name or IP address, without http://, a path or a port.")
        }
        // Remove an interface scope such as fe80::1%en0.
        if let pct = host.firstIndex(of: "%") { host = String(host[host.startIndex..<pct]) }

        if host.contains(":") { return checkIPv6(host) }

        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            let nums = parts.compactMap { Int($0) }
            guard nums.count == 4, nums.allSatisfy({ $0 >= 0 && $0 <= 255 }) else {
                return Verdict(allowed: false, reason: "That is not a valid IPv4 address.")
            }
            let a = nums[0], b = nums[1]
            if a == 10 { return Verdict(allowed: true, reason: "Private address (10.0.0.0/8).") }
            if a == 172 && (16...31).contains(b) { return Verdict(allowed: true, reason: "Private address (172.16.0.0/12).") }
            if a == 192 && b == 168 { return Verdict(allowed: true, reason: "Private address (192.168.0.0/16).") }
            if a == 169 && b == 254 { return Verdict(allowed: true, reason: "Link-local address (169.254.0.0/16).") }
            if a == 127 { return Verdict(allowed: false, reason: "That address points at this device itself, not another device on your network.") }
            return Verdict(allowed: false, reason: refusal)
        }

        var name = host
        if name.hasSuffix(".") { name = String(name.dropLast()) }
        if name.hasSuffix(".local"), name.count > ".local".count, name.count <= 253 {
            let ok = name.unicodeScalars.allSatisfy { s in
                (s.value >= 97 && s.value <= 122) || (s.value >= 48 && s.value <= 57) || s == "-" || s == "." || s == "_"
            }
            if ok { return Verdict(allowed: true, reason: "Local name (.local).") }
        }
        return Verdict(allowed: false, reason: refusal)
    }

    private static func checkIPv6(_ host: String) -> Verdict {
        var addr = in6_addr()
        guard inet_pton(AF_INET6, host, &addr) == 1 else {
            return Verdict(allowed: false, reason: "That is not a valid IPv6 address.")
        }
        let bytes: [UInt8] = withUnsafeBytes(of: &addr) { Array($0) }
        guard bytes.count == 16 else { return Verdict(allowed: false, reason: "That is not a valid IPv6 address.") }
        if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return Verdict(allowed: true, reason: "Link-local address (fe80::/10).") }
        if (bytes[0] & 0xfe) == 0xfc { return Verdict(allowed: true, reason: "Unique local address (fc00::/7).") }
        return Verdict(allowed: false, reason: refusal)
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
