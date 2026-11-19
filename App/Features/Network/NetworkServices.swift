import Foundation
import Network
import Security
import Observation

// MARK: - Scope guard (remembered once, because iOS does not let apps read the Wi-Fi name without extra entitlements)

@MainActor @Observable
final class NetScope {
    private static let key = "assay.network.scopeAccepted"
    private(set) var accepted: Bool

    init() {
        accepted = UserDefaults.standard.bool(forKey: NetScope.key)
    }

    func accept() {
        accepted = true
        UserDefaults.standard.set(true, forKey: NetScope.key)
    }

    func reset() {
        accepted = false
        UserDefaults.standard.removeObject(forKey: NetScope.key)
    }
}

// MARK: - Small concurrency helper

/// Lets a callback-based API resume a continuation exactly once.
final class NetOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

// MARK: - Bonjour browser

enum NetPermission: Equatable {
    case notChecked
    case checking
    case allowedInferred
    case denied
}

@MainActor @Observable
final class NetBonjourService {
    private(set) var services: [NetFoundService] = []
    private(set) var isBrowsing = false
    private(set) var permission: NetPermission = .notChecked
    private(set) var lastError: String?
    private(set) var startedAt: Date?

    private(set) var demoEnabled = false
    private(set) var demoServices: [NetFoundService] = []

    func setDemo(_ on: Bool) {
        demoEnabled = on
        demoServices = on ? NetDemo.make() : []
    }

    @ObservationIgnored private var browsers: [String: NWBrowser] = [:]
    @ObservationIgnored private var visibleScreens = 0
    @ObservationIgnored private var endpoints: [String: NWEndpoint] = [:]

    /// Real results plus demo results (when the Demo toggle is on). Demo entries always carry isDemo.
    var allServices: [NetFoundService] { services + demoServices }

    var devices: [NetDevice] {
        let grouped = Dictionary(grouping: allServices, by: { $0.name })
        return grouped
            .map { NetDevice(name: $0.key, services: $0.value.sorted { $0.type < $1.type }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func device(named name: String) -> NetDevice? {
        let s = allServices.filter { $0.name == name }
        return s.isEmpty ? nil : NetDevice(name: name, services: s.sorted { $0.type < $1.type })
    }

    func service(id: String) -> NetFoundService? { allServices.first { $0.id == id } }

    // MARK: Browsing

    /// Starts one NWBrowser per fixed service type. The caller must have checked the scope guard first.
    func start() {
        guard !isBrowsing else { return }
        isBrowsing = true
        permission = .checking
        lastError = nil
        startedAt = Date()
        for kind in NetServiceKind.all {
            let type = kind.type
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: "local."), using: .tcp)
            browser.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in self?.handleState(state, type: type) }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor [weak self] in self?.handleResults(results, type: type) }
            }
            browsers[type] = browser
            browser.start(queue: .main)
        }
    }

    func stop() {
        for (_, b) in browsers { b.cancel() }
        browsers.removeAll()
        isBrowsing = false
        if permission == .checking { permission = .notChecked }
        for i in services.indices where services[i].resolve == .resolving { services[i].resolve = .idle }
    }

    /// Each screen reports when it is on screen; browsing stops shortly after the last one goes away.
    func screenAppeared() { visibleScreens += 1 }

    func screenDisappeared() {
        visibleScreens = max(0, visibleScreens - 1)
        guard visibleScreens == 0 else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, self.visibleScreens == 0 else { return }
            self.stop()
        }
    }

    func clearResults() {
        services.removeAll()
        endpoints.removeAll()
    }

    private func handleState(_ state: NWBrowser.State, type: String) {
        guard isBrowsing else { return }
        switch state {
        case .ready:
            if permission != .denied { permission = .allowedInferred }
        case .waiting(let error):
            if Self.isPolicyDenied(error) { markDenied() }
            else { lastError = "Network not ready: \(error.localizedDescription)" }
        case .failed(let error):
            if Self.isPolicyDenied(error) { markDenied() }
            else { lastError = "Browsing \(type) failed: \(error.localizedDescription)" }
        default:
            break
        }
    }

    private func markDenied() {
        permission = .denied
        lastError = "Local Network access is off for Assay."
        for (_, b) in browsers { b.cancel() }
        browsers.removeAll()
        isBrowsing = false
    }

    /// kDNSServiceErr_PolicyDenied is -65570. iOS has no API to read the Local Network setting; this is the only signal.
    private static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == -65570 }
        return false
    }

    private static func interfaceLabel(_ ifaces: [NWInterface]) -> String {
        var seen: [String] = []
        for i in ifaces {
            let kind: String
            switch i.type {
            case .wifi: kind = "Wi-Fi"
            case .wiredEthernet: kind = "Ethernet"
            case .cellular: kind = "Cellular"
            case .loopback: kind = "Loopback"
            default: kind = "Other"
            }
            let s = "\(i.name) · \(kind)"
            if !seen.contains(s) { seen.append(s) }
        }
        return seen.isEmpty ? "Not reported" : seen.joined(separator: ", ")
    }

    private func handleResults(_ results: Set<NWBrowser.Result>, type: String) {
        guard isBrowsing else { return }
        let now = Date()
        permission = .allowedInferred
        var present: Set<String> = []

        for r in results {
            guard case let .service(name, svcType, domain, _) = r.endpoint else { continue }
            let normType = NetServiceKind.normaliseType(svcType)
            let id = "\(name)|\(normType)|\(domain)"
            present.insert(id)
            var keys: [String] = []
            if case let .bonjour(txt) = r.metadata { keys = txt.dictionary.keys.sorted() }
            let iface = Self.interfaceLabel(r.interfaces)
            endpoints[id] = r.endpoint

            if let i = services.firstIndex(where: { $0.id == id }) {
                services[i].lastSeen = now
                services[i].isPresent = true
                services[i].interface = iface
                if !keys.isEmpty { services[i].txtKeys = keys }
            } else {
                services.append(NetFoundService(id: id, name: name, type: normType, domain: domain, interface: iface,
                                           txtKeys: keys, host: nil, port: nil, resolve: .idle,
                                           firstSeen: now, lastSeen: now))
            }
        }
        // Anything of this type that is no longer advertised stays in the list, marked as gone, with its last-seen time.
        for i in services.indices where services[i].type == type && !present.contains(services[i].id) {
            services[i].isPresent = false
        }
    }

    // MARK: Lazy resolve (one service, when the user opens the device)

    func resolve(id: String) {
        guard let i = services.firstIndex(where: { $0.id == id }) else { return }
        switch services[i].resolve {
        case .resolving, .resolved: return
        default: break
        }
        guard let endpoint = endpoints[id] else {
            services[i].resolve = .failed("The service is no longer advertised.")
            return
        }
        services[i].resolve = .resolving
        Task { [weak self] in
            let outcome = await NetResolver.resolve(endpoint: endpoint, timeout: 5)
            guard let self else { return }
            self.apply(outcome, id: id)
        }
    }

    private func apply(_ outcome: NetResolveOutcome, id: String) {
        guard let j = services.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .success(let host, let port):
            services[j].host = host
            services[j].port = port
            services[j].resolve = .resolved
        case .failure(let msg):
            services[j].resolve = .failed(msg)
        }
    }

    /// Resolves the services of one device the user opened. Never called for the whole list.
    func resolveAll(inDevice name: String) {
        for s in services where s.name == name { resolve(id: s.id) }
    }

    func retryResolve(id: String) {
        if let i = services.firstIndex(where: { $0.id == id }), case .failed = services[i].resolve {
            services[i].resolve = .idle
        }
        resolve(id: id)
    }
}

// MARK: - Resolver (one TCP connect to the advertised service, to read the host and port the system chose, then cancel)

enum NetResolveOutcome: Sendable {
    case success(host: String, port: UInt16)
    case failure(String)
}

enum NetResolver {
    static func resolve(endpoint: NWEndpoint, timeout: TimeInterval) async -> NetResolveOutcome {
        let conn = NWConnection(to: endpoint, using: .tcp)
        let gate = NetOnce()
        let queue = DispatchQueue(label: "assay.net.resolve")
        return await withCheckedContinuation { (cont: CheckedContinuation<NetResolveOutcome, Never>) in
            @Sendable func finish(_ r: NetResolveOutcome) {
                if gate.fire() { conn.cancel(); cont.resume(returning: r) }
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let remote = conn.currentPath?.remoteEndpoint, case let .hostPort(host, port) = remote {
                        finish(.success(host: NetResolver.describe(host), port: port.rawValue))
                    } else {
                        finish(.failure("Connected, but iOS did not report an address."))
                    }
                case .failed(let e):
                    finish(.failure("Could not connect: \(e.localizedDescription). Some services advertise a name but accept no TCP connection."))
                case .waiting(let e):
                    if case .dns(let code) = e, code == -65570 { finish(.failure("Local Network access is off for Assay.")) }
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure("No answer within \(Int(timeout)) s. The service may not accept TCP connections."))
            }
            conn.start(queue: queue)
        }
    }

    static func describe(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let a): return "\(a)"
        case .ipv6(let a): return "\(a)"
        case .name(let n, _): return n
        @unknown default: return "\(host)"
        }
    }
}

// MARK: - TCP connect probe (latency)

enum NetTCPProbe {
    /// One TCP connect. Returns milliseconds to reach the ready state, or nil on refusal or timeout. No data is sent.
    static func connectOnce(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        guard let p = NWEndpoint.Port(rawValue: port) else { return nil }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        let gate = NetOnce()
        let queue = DispatchQueue(label: "assay.net.probe")
        let startNs = DispatchTime.now().uptimeNanoseconds
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            @Sendable func finish(_ v: Double?) {
                if gate.fire() { conn.cancel(); cont.resume(returning: v) }
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ns = DispatchTime.now().uptimeNanoseconds &- startNs
                    finish(Double(ns) / 1_000_000)
                case .failed:
                    finish(nil)
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
            conn.start(queue: queue)
        }
    }
}
