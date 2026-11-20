import Foundation
import Security
import Observation

// MARK: - TLS inspection (inspect the trust, then cancel; never accept it, never send credentials)

final class NetTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var captured: NetCertInfo?

    var info: NetCertInfo? {
        lock.lock(); defer { lock.unlock() }
        return captured
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Anything other than a server trust challenge (for example a password request) is refused with no credential.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        var evalError: CFError?
        let trusted = SecTrustEvaluateWithError(trust, &evalError)
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first {
            var parsed = NetCertParser.parse(leaf)
            parsed.trustedByDevice = trusted
            lock.lock(); captured = parsed; lock.unlock()
        }
        // Always cancel: the connection is never allowed to carry a request, whatever the trust result.
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

enum NetCertInspector {
    static func inspect(host: String, port: UInt16) async -> (info: NetCertInfo?, error: String?) {
        let bare = host
        let hostPart = bare.contains(":") ? "[\(bare.replacingOccurrences(of: "%", with: "%25"))]" : bare
        guard let url = URL(string: "https://\(hostPart):\(port)/") else { return (nil, "That address cannot be used in a URL.") }

        let delegate = NetTrustDelegate()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        cfg.timeoutIntervalForResource = 5
        cfg.waitsForConnectivity = false
        cfg.urlCache = nil
        cfg.urlCredentialStorage = nil
        cfg.httpCookieStorage = nil
        cfg.httpShouldSetCookies = false
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: cfg, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 5

        var failure: Error?
        do { _ = try await session.data(for: req) } catch { failure = error }

        if let info = delegate.info { return (info, nil) }
        if let u = failure as? URLError {
            switch u.code {
            case .timedOut: return (nil, "No answer within 5 s.")
            case .cannotConnectToHost: return (nil, "Connection refused. Nothing is listening for HTTPS on that port.")
            case .cannotFindHost, .dnsLookupFailed: return (nil, "The name could not be found on this network.")
            case .notConnectedToInternet: return (nil, "No network connection.")
            default: return (nil, "No certificate was received: \(u.localizedDescription)")
            }
        }
        return (nil, "No certificate was received. The service may not speak TLS on that port.")
    }
}

// MARK: - Minimal DER reader (Security has no public iOS API for issuer text or validity dates)

enum NetCertParser {
    private struct Item { let tag: UInt8; let content: Range<Int>; let full: Range<Int> }

    private static func item(_ b: [UInt8], _ pos: Int) -> Item? {
        guard pos >= 0, pos + 2 <= b.count else { return nil }
        let tag = b[pos]
        var idx = pos + 1
        var len = Int(b[idx]); idx += 1
        if len & 0x80 != 0 {
            let n = len & 0x7f
            guard n >= 1, n <= 4, idx + n <= b.count else { return nil }
            len = 0
            for _ in 0..<n { len = (len << 8) | Int(b[idx]); idx += 1 }
        }
        guard idx + len <= b.count else { return nil }
        return Item(tag: tag, content: idx..<(idx + len), full: pos..<(idx + len))
    }

    private static func children(_ b: [UInt8], _ parent: Item) -> [Item] {
        var out: [Item] = []
        var pos = parent.content.lowerBound
        while pos < parent.content.upperBound, let it = item(b, pos) {
            out.append(it)
            pos = it.full.upperBound
        }
        return out
    }

    private static func text(_ b: [UInt8], _ it: Item) -> String? {
        let bytes = Array(b[it.content])
        if it.tag == 0x1E {   // BMPString, UTF-16 big endian
            var units: [UInt16] = []
            var i = 0
            while i + 1 < bytes.count { units.append(UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1])); i += 2 }
            return String(decoding: units, as: UTF16.self)
        }
        return String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .isoLatin1)
    }

    /// Returns (common name, organisation) from a Name.
    private static func nameParts(_ b: [UInt8], _ name: Item) -> (cn: String?, org: String?) {
        var cn: String?
        var org: String?
        for rdn in children(b, name) {
            for atv in children(b, rdn) {
                let parts = children(b, atv)
                guard parts.count == 2 else { continue }
                let oid = Array(b[parts[0].content])
                if oid == [0x55, 0x04, 0x03] { cn = text(b, parts[1]) }
                if oid == [0x55, 0x04, 0x0A] { org = text(b, parts[1]) }
            }
        }
        return (cn, org)
    }

    private static func summary(_ p: (cn: String?, org: String?)) -> String {
        if let c = p.cn, let o = p.org, c != o { return "\(c) (\(o))" }
        if let c = p.cn { return c }
        if let o = p.org { return o }
        return "Not available"
    }

    private static func time(_ b: [UInt8], _ it: Item) -> Date? {
        guard it.tag == 0x17 || it.tag == 0x18, let s = String(bytes: b[it.content], encoding: .ascii) else { return nil }
        let chars = Array(s.hasSuffix("Z") ? String(s.dropLast()) : s)
        let yl = it.tag == 0x17 ? 2 : 4
        func n(_ a: Int, _ l: Int) -> Int? {
            guard a + l <= chars.count else { return nil }
            return Int(String(chars[a..<(a + l)]))
        }
        guard var year = n(0, yl), let mo = n(yl, 2), let d = n(yl + 2, 2), let h = n(yl + 4, 2), let mi = n(yl + 6, 2) else { return nil }
        let sec = n(yl + 8, 2) ?? 0
        if it.tag == 0x17 { year += year < 50 ? 2000 : 1900 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return cal.date(from: DateComponents(year: year, month: mo, day: d, hour: h, minute: mi, second: sec))
    }

    static func parse(_ cert: SecCertificate) -> NetCertInfo {
        let summaryName = SecCertificateCopySubjectSummary(cert) as String?
        var info = NetCertInfo(subject: summaryName ?? "Not available",
                               issuer: "Not available", notBefore: nil, notAfter: nil,
                               keyType: "Not available", keyBits: nil, isRSA: false, selfSigned: false, trustedByDevice: nil)

        // Key type and size from Security.
        if let key = SecCertificateCopyKey(cert), let attrs = SecKeyCopyAttributes(key) as? [String: Any] {
            let type = attrs[kSecAttrKeyType as String] as? String
            info.isRSA = (type == (kSecAttrKeyTypeRSA as String))
            if info.isRSA { info.keyType = "RSA" }
            else if type == (kSecAttrKeyTypeECSECPrimeRandom as String) { info.keyType = "Elliptic curve" }
            else if let type { info.keyType = type }
            info.keyBits = attrs[kSecAttrKeySizeInBits as String] as? Int
        }

        // Issuer, validity and self-signed from the DER.
        let der = [UInt8](SecCertificateCopyData(cert) as Data)
        guard let top = item(der, 0), top.tag == 0x30,
              let tbs = children(der, top).first, tbs.tag == 0x30 else { return info }
        let f = children(der, tbs)
        let o = (f.first?.tag == 0xA0) ? 1 : 0
        guard f.count >= o + 5 else { return info }
        let issuer = f[o + 2], validity = f[o + 3], subject = f[o + 4]
        info.issuer = summary(nameParts(der, issuer))
        let subj = summary(nameParts(der, subject))
        if subj != "Not available" { info.subject = subj }
        let times = children(der, validity)
        if times.count == 2 {
            info.notBefore = time(der, times[0])
            info.notAfter = time(der, times[1])
        }
        info.selfSigned = Array(der[issuer.full]) == Array(der[subject.full])
        return info
    }
}

// MARK: - Probe store: one test at a time, results kept for the session

@MainActor @Observable
final class NetProbeStore {
    private(set) var activeKey: String?
    private(set) var live: [Double?] = []
    private(set) var latency: [String: NetLatencyResult] = [:]
    private(set) var cert: [String: NetCertResult] = [:]
    private(set) var notices: [String: String] = [:]

    var isBusy: Bool { activeKey != nil }

    enum Source { case discovered, manual }

    static func key(host: String, port: UInt16, demo: Bool) -> String {
        "\(demo ? "demo|" : "")\(host):\(port)"
    }

    private func verdict(host: String, source: Source) -> NetAddressPolicy.Verdict {
        source == .manual ? NetAddressPolicy.check(host) : NetAddressPolicy.checkDiscovered(host)
    }

    func runLatency(host: String, port: UInt16, source: Source, demo: [Double?]? = nil) async {
        let key = Self.key(host: host, port: port, demo: demo != nil)
        guard activeKey == nil else { return }
        notices[key] = nil
        let target = verdict(host: host, source: source)
        if demo == nil && !target.allowed { notices[key] = target.reason; return }
        activeKey = "latency|" + key
        live = []
        defer { activeKey = nil }

        var samples: [Double?] = []
        if let demo {
            for s in demo {
                try? await Task.sleep(for: .milliseconds(250))
                samples.append(s); live = samples
            }
        } else if let host = target.host {
            for i in 0..<5 {
                if Task.isCancelled { break }
                let ms = await NetTCPProbe.connectOnce(host: host, port: port, timeout: 2)
                samples.append(ms); live = samples
                if i < 4 { try? await Task.sleep(for: .milliseconds(150)) }
            }
        }
        latency[key] = NetLatencyResult(samples: samples, date: Date(), isDemo: demo != nil)
    }

    func runCert(host: String, port: UInt16, source: Source, demo: NetCertInfo? = nil) async {
        let key = Self.key(host: host, port: port, demo: demo != nil)
        guard activeKey == nil else { return }
        notices[key] = nil
        let target = verdict(host: host, source: source)
        if demo == nil && !target.allowed { notices[key] = target.reason; return }
        activeKey = "cert|" + key
        defer { activeKey = nil }

        if let demo {
            try? await Task.sleep(for: .milliseconds(500))
            cert[key] = NetCertResult(info: demo, error: nil, date: Date())
            return
        }
        guard let host = target.host else { return }
        let r = await NetCertInspector.inspect(host: host, port: port)
        cert[key] = NetCertResult(info: r.info, error: r.error, date: Date())
    }

    func isRunning(latencyFor key: String) -> Bool { activeKey == "latency|" + key }
    func isRunning(certFor key: String) -> Bool { activeKey == "cert|" + key }
}

// MARK: - Plain-text report

@MainActor
enum NetReport {
    static func text(devices: [NetDevice], probes: NetProbeStore, demo: Bool, now: Date = Date()) -> String {
        var out: [String] = []
        out.append("Assay local network inventory")
        out.append("Generated: \(now.formatted(date: .abbreviated, time: .shortened))")
        out.append("Method: Bonjour browsing, TCP connect timing and TLS certificate inspection only.")
        out.append("Not included: ARP, ICMP ping, port scanning, or any device that does not advertise over Bonjour.")
        if demo { out.append("DEMO: entries marked [DEMO] are simulated samples, not real devices.") }
        out.append("")
        if devices.isEmpty { out.append("No devices were listed.") }
        for d in devices {
            let gone = d.isPresent ? "" : " (no longer advertised)"
            out.append("\(d.name)\(d.isDemo ? " [DEMO]" : "") · \(d.count) service\(d.count == 1 ? "" : "s") · last seen \(d.lastSeen.formatted(date: .omitted, time: .shortened))\(gone)")
            for s in d.services {
                var line = "  - \(NetServiceKind.title(for: s.type)) (\(s.type)) on \(s.domain), \(s.interface)"
                if let hp = s.hostPortKey { line += ", \(hp)" } else { line += ", not resolved" }
                out.append(line)
                if !s.txtKeys.isEmpty { out.append("    TXT keys: \(s.txtKeys.joined(separator: ", "))") }
                guard let host = s.host, let port = s.port else { continue }
                let key = NetProbeStore.key(host: host, port: port, demo: s.isDemo)
                if let l = probes.latency[key] {
                    if let mn = l.minMs, let av = l.avgMs, let mx = l.maxMs {
                        out.append("    TCP connect: min \(fmt(mn)) ms, avg \(fmt(av)) ms, max \(fmt(mx)) ms, loss \(l.lost) of \(l.samples.count)\(l.isDemo ? " [DEMO]" : "")")
                    } else {
                        out.append("    TCP connect: no reply, loss \(l.lost) of \(l.samples.count)\(l.isDemo ? " [DEMO]" : "")")
                    }
                }
                if let c = probes.cert[key] {
                    if let i = c.info {
                        var flags: [String] = []
                        if i.isExpired() { flags.append("Expired") }
                        if i.isWeak { flags.append("Weak key") }
                        if i.selfSigned { flags.append("Self-signed") }
                        let left: String
                        if let dl = i.daysLeft() { left = dl >= 0 ? "\(dl) days left" : "expired \(-dl) days ago" } else { left = "validity unknown" }
                        let bits = i.keyBits.map { String($0) } ?? "?"
                        let flagText = flags.isEmpty ? "" : " [" + flags.joined(separator: ", ") + "]"
                        out.append("    Certificate: \(i.subject), issuer \(i.issuer), \(left), \(i.keyType) \(bits)\(flagText)\(i.isDemo ? " [DEMO]" : "")")
                    } else if let e = c.error {
                        out.append("    Certificate: not read (\(e))")
                    }
                }
            }
            out.append("")
        }
        out.append("Limits: iOS gives apps no ARP table, no ping and no raw sockets. This report is not an Nmap equivalent.")
        return out.joined(separator: "\n")
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
}
