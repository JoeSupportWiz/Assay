import SwiftUI
import UIKit

// MARK: - Routes

enum NetRoute: Hashable {
    case device(String)
    case manual
}

// MARK: - Root

/// Local network inventory. Place it inside a NavigationStack; it registers its own destinations.
struct NetworkRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @Environment(\.scenePhase) private var scenePhase

    @State private var scope = NetScope()
    @State private var bonjour = NetBonjourService()
    @State private var probes = NetProbeStore()
    @State private var showScope = false
    @State private var confirmReset = false

    var body: some View {
        List {
            statusSection
            devicesSection
            toolsSection
            demoSection
            scopeSection
            Section {
                Text("Honest limits: iOS gives apps no ARP table, no ping or ICMP and no raw sockets. This is Bonjour browsing, a TCP connect and TLS inspection. It is not an Nmap equivalent, and it only sees devices that advertise themselves.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Local network")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NetRoute.self) { route in
            switch route {
            case .device(let name): NetDeviceView(deviceName: name, bonjour: bonjour, probes: probes)
            case .manual: NetManualView(probes: probes, scopeAccepted: scope.accepted)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: NetReport.text(devices: bonjour.devices, probes: probes, demo: bonjour.demoEnabled)) {
                    Label("Share report", systemImage: "square.and.arrow.up")
                }
                .disabled(bonjour.devices.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) { primaryAction }
        .sheet(isPresented: $showScope) { NetScopeSheet(scope: scope, isPresented: $showScope) }
        .confirmationDialog("Reset the scope confirmation?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset and stop browsing", role: .destructive) {
                bonjour.stop()
                scope.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be asked to confirm again before Assay looks at a network.")
        }
        .onAppear {
            bonjour.screenAppeared()
            if !scope.accepted { showScope = true }
        }
        .onDisappear { bonjour.screenDisappeared() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { bonjour.stop() }
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                IconTile(symbol: "wifi", hue: .sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Network access").foregroundStyle(t.ink)
                    Text(permissionText).font(.system(size: 13)).foregroundStyle(t.ink2)
                }
                Spacer(minLength: 8)
                permissionTag
            }
            if bonjour.permission == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: { Label("Open Settings", systemImage: "gearshape") }
            }
            if let e = bonjour.lastError, bonjour.permission != .denied {
                Label(e, systemImage: "exclamationmark.triangle").font(.system(size: 13)).foregroundStyle(t.ink2)
            }
        } header: { Text("Permission") } footer: {
            Text("iOS asks once for Local Network access so Assay can find devices that advertise over Bonjour, such as printers, speakers and web interfaces. Assay does not use it for anything else. iOS has no way to read the setting, so this status is inferred from whether browsing works.")
        }.rowCard()
    }

    private var permissionText: String {
        switch bonjour.permission {
        case .notChecked: return "Not checked. Start browsing to find out."
        case .checking: return "Waiting for iOS to answer."
        case .allowedInferred: return "Browsing works, so access is on."
        case .denied: return "Off. Turn on Local Network for Assay in Settings."
        }
    }

    @ViewBuilder private var permissionTag: some View {
        switch bonjour.permission {
        case .notChecked: Tag(style: .unknown)
        case .checking: Tag(style: .neutral, text: "Checking")
        case .allowedInferred: Tag(style: .inferred(nil))
        case .denied: Tag(style: .caution, text: "Denied")
        }
    }

    private var devicesSection: some View {
        Section {
            let devices = bonjour.devices
            if devices.isEmpty {
                if bonjour.isBrowsing {
                    HStack(spacing: 10) { ProgressView(); Text("Looking for services").foregroundStyle(t.ink2) }
                } else if !scope.accepted {
                    Label("Confirm the scope to start browsing.", systemImage: "hand.raised").foregroundStyle(t.ink2)
                } else if bonjour.permission == .denied {
                    Label("Nothing to show while Local Network is off.", systemImage: "wifi.slash").foregroundStyle(t.ink2)
                } else {
                    Label("Nothing found yet. Start browsing, or turn on Demo to preview the screens.", systemImage: "questionmark.circle").foregroundStyle(t.ink2)
                }
            } else {
                ForEach(devices) { d in
                    NavigationLink(value: NetRoute.device(d.name)) { NetDeviceRow(device: d) }
                }
            }
        } header: {
            HStack {
                Text("Devices")
                Spacer()
                if bonjour.isBrowsing && !bonjour.devices.isEmpty { ProgressView().controlSize(.small) }
            }
        } footer: {
            Text("Grouped by service name. Addresses are only looked up when you open a device.")
        }.rowCard()
    }

    private var toolsSection: some View {
        Section("Test an address") {
            NavigationLink(value: NetRoute.manual) {
                Label("Type an address", systemImage: "keyboard")
            }
        }.rowCard()
    }

    private var demoSection: some View {
        Section {
            Toggle(isOn: Binding(get: { bonjour.demoEnabled }, set: { bonjour.setDemo($0) })) {
                HStack(spacing: 8) { Text("Demo services"); Tag(style: .neutral, text: "Demo") }
            }
        } footer: {
            Text("Adds six simulated services, including one expired certificate and one weak key, so the screens can be previewed. They are not real devices and no network traffic is sent for them.")
        }.rowCard()
    }

    private var scopeSection: some View {
        Section {
            LabeledContent("Scope confirmed", value: scope.accepted ? "Yes" : "No")
            if scope.accepted {
                Button("Reset", role: .destructive) { confirmReset = true }
            } else {
                Button("Review and confirm") { showScope = true }
            }
        } header: { Text("Scope") } footer: {
            Text("Assay only looks at networks you own or are allowed to test. No port scanning, no credential guessing, no exploit attempts.")
        }.rowCard()
    }

    // MARK: Pinned action

    private var primaryAction: some View {
        Button {
            if !scope.accepted { showScope = true; return }
            if bonjour.isBrowsing {
                bonjour.stop()
            } else {
                bonjour.start()
            }
        } label: {
            Text(!scope.accepted ? "Review scope" : (bonjour.isBrowsing ? "Stop browsing" : "Start browsing"))
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Device row

struct NetDeviceRow: View {
    @Environment(\.theme) private var t
    let device: NetDevice

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, hue: device.isDemo ? .butter : .mint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name).foregroundStyle(t.ink).lineLimit(1)
                    if device.isDemo { Tag(style: .neutral, text: "Demo") }
                }
                HStack(spacing: 6) {
                    Text("\(device.count) service\(device.count == 1 ? "" : "s")")
                    Text("·")
                    Text("last seen ") + Text(device.lastSeen, format: .relative(presentation: .numeric))
                }
                .font(.system(size: 13)).foregroundStyle(t.ink2)
                if !device.isPresent {
                    Text("No longer advertised").font(.system(size: 12.5)).foregroundStyle(t.ink3)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        let types = device.services.map(\.type)
        if types.contains(where: { $0 == "_ipp._tcp" || $0 == "_printer._tcp" }) { return "printer" }
        if types.contains(where: { $0 == "_airplay._tcp" || $0 == "_raop._tcp" || $0 == "_googlecast._tcp" || $0 == "_spotify-connect._tcp" }) { return "hifispeaker" }
        if types.contains("_hap._tcp") { return "homekit" }
        if types.contains("_smb._tcp") { return "externaldrive" }
        if types.contains("_ssh._tcp") { return "terminal" }
        if types.contains(where: { $0 == "_http._tcp" || $0 == "_https._tcp" }) { return "globe" }
        return "dot.radiowaves.left.and.right"
    }
}

// MARK: - Device detail

struct NetDeviceView: View {
    @Environment(\.theme) private var t
    let deviceName: String
    let bonjour: NetBonjourService
    let probes: NetProbeStore

    var body: some View {
        List {
            if let device = bonjour.device(named: deviceName) {
                Section {
                    LabeledContent("Services", value: "\(device.count)")
                    LabeledContent("Last seen") { Text(device.lastSeen, format: .relative(presentation: .numeric)) }
                    if device.isDemo {
                        HStack { Text("Source").foregroundStyle(t.ink); Spacer(); Tag(style: .neutral, text: "Demo") }
                    }
                } footer: {
                    Text(device.isDemo ? "Simulated sample. Not a real device." : "Addresses below are looked up once, when this screen opens.")
                }.rowCard()

                ForEach(device.services) { s in
                    NetServiceSection(service: s, bonjour: bonjour, probes: probes)
                }
            } else {
                Section {
                    Label("This device is no longer in the list.", systemImage: "questionmark.circle").foregroundStyle(t.ink2)
                }.rowCard()
            }
            Section {
                Text("TCP connect time and TLS inspection only. No ping, no ARP, no port scan.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }.rowCard()
        }
        .themedList()
        .navigationTitle(deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bonjour.screenAppeared()
            bonjour.resolveAll(inDevice: deviceName)
        }
        .onDisappear { bonjour.screenDisappeared() }
    }
}

struct NetServiceSection: View {
    @Environment(\.theme) private var t
    let service: NetFoundService
    let bonjour: NetBonjourService
    let probes: NetProbeStore

    private var key: String? {
        guard let h = service.host, let p = service.port else { return nil }
        return NetProbeStore.key(host: h, port: p, demo: service.isDemo)
    }

    private var tlsCapable: Bool {
        (service.kind?.tlsCapable ?? false) || service.port == 443
    }

    var body: some View {
        Section {
            LabeledContent("Type", value: service.type)
            LabeledContent("Domain", value: service.domain)
            LabeledContent("Interface", value: service.interface)
            LabeledContent("Last seen") { Text(service.lastSeen, format: .relative(presentation: .numeric)) }
            addressRows
            LabeledContent("TXT keys") {
                Text(service.txtKeys.isEmpty ? "None advertised" : service.txtKeys.joined(separator: ", "))
                    .multilineTextAlignment(.trailing)
            }
            if let host = service.host, let port = service.port, let key {
                Button {
                    Task { await probes.runLatency(host: host, port: port, source: .discovered, demo: service.demoLatency) }
                } label: { Label("Test connect time", systemImage: "timer") }
                .disabled(probes.isBusy || !service.isPresent && !service.isDemo)
                NetLatencyRows(probes: probes, key: key)

                if tlsCapable {
                    Button {
                        Task { await probes.runCert(host: host, port: port, source: .discovered, demo: service.demoCert) }
                    } label: { Label("Check certificate", systemImage: "checkmark.seal") }
                    .disabled(probes.isBusy || !service.isPresent && !service.isDemo)
                    NetCertRows(probes: probes, key: key)
                }
                if probes.isBusy && !probes.isRunning(latencyFor: key) && !probes.isRunning(certFor: key) {
                    Text("Another test is running. Assay runs one at a time.").font(.system(size: 12.5)).foregroundStyle(t.ink3)
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text(NetServiceKind.title(for: service.type))
                if service.isDemo { Tag(style: .neutral, text: "Demo") }
            }
        }.rowCard()
    }

    @ViewBuilder private var addressRows: some View {
        switch service.resolve {
        case .idle:
            LabeledContent("Address", value: "Not looked up yet")
        case .resolving:
            HStack(spacing: 10) { ProgressView(); Text("Looking up address").foregroundStyle(t.ink2) }
        case .resolved:
            LabeledContent("Host", value: service.host ?? "Not available")
            LabeledContent("Port", value: service.port.map { String($0) } ?? "Not available")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").font(.system(size: 13.5)).foregroundStyle(t.ink2)
            Button("Try again") { bonjour.retryResolve(id: service.id) }
        }
    }
}

// MARK: - Typed address

struct NetManualView: View {
    @Environment(\.theme) private var t
    let probes: NetProbeStore
    let scopeAccepted: Bool
    @State private var host = ""
    @State private var portText = "443"

    private var port: UInt16? {
        guard let n = Int(portText.trimmingCharacters(in: .whitespaces)), (1...65535).contains(n) else { return nil }
        return UInt16(n)
    }
    private var cleanHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var verdict: NetAddressPolicy.Verdict { NetAddressPolicy.check(host) }
    private var key: String? { port.map { NetProbeStore.key(host: cleanHost, port: $0, demo: false) } }
    private var canRun: Bool { scopeAccepted && verdict.allowed && port != nil && !probes.isBusy }

    var body: some View {
        List {
            Section {
                TextField("192.168.1.20 or printer.local", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                TextField("Port", text: $portText).keyboardType(.numberPad)
            } header: { Text("Address") } footer: {
                if cleanHost.isEmpty {
                    Text("Private addresses (10.x, 172.16–31.x, 192.168.x), link-local addresses and .local names only.")
                } else if verdict.allowed {
                    Text(verdict.reason)
                } else {
                    Text(verdict.reason).foregroundStyle(t.ink)
                }
            }.rowCard()

            if !scopeAccepted {
                Section {
                    Label("Confirm “I’m allowed to inspect this network” on the Local network screen before testing.", systemImage: "hand.raised").foregroundStyle(t.ink2)
                }.rowCard()
            }

            if let key, verdict.allowed {
                Section("Connect time") {
                    Button {
                        if let p = port { Task { await probes.runLatency(host: cleanHost, port: p, source: .manual) } }
                    } label: { Label("Test", systemImage: "timer") }.disabled(!canRun)
                    NetLatencyRows(probes: probes, key: key)
                }.rowCard()

                Section("Certificate") {
                    Button {
                        if let p = port { Task { await probes.runCert(host: cleanHost, port: p, source: .manual) } }
                    } label: { Label("Check certificate", systemImage: "checkmark.seal") }.disabled(!canRun)
                    NetCertRows(probes: probes, key: key)
                }.rowCard()
            } else if !cleanHost.isEmpty {
                Section {
                    Label("Not tested: \(verdict.reason)", systemImage: "hand.raised").foregroundStyle(t.ink2)
                }.rowCard()
            }

            Section {
                Text("Assay refuses public addresses. It runs one test at a time, never sends credentials, and never scans ports.")
                    .font(.system(size: 12.5)).foregroundStyle(t.ink3)
            }.rowCard()
        }
        .themedList()
        .navigationTitle("Type an address")
        .navigationBarTitleDisplayMode(.inline)
    }
}
