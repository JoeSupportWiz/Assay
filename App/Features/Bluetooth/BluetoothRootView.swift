import SwiftUI
import UIKit

// MARK: - Root view

struct BluetoothRootView: View {
    @Environment(\.theme) private var t
    @Environment(\.scenePhase) private var scenePhase
    @State private var scanner = BLEScanner()
    @State private var query = ""
    @State private var exportText: String?

    var body: some View {
        List {
            modeSection
            if !scanner.demoMode && scanner.authState != .poweredOn { stateSection }
            deviceSections
            companySection
            footerSection
        }
        .themedList()
        .navigationTitle("Bluetooth")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Name, UUID or service")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { exportText = scanner.sessionLog() } label: { Label("Export log", systemImage: "square.and.arrow.up") }
            }
        }
        .safeAreaInset(edge: .bottom) { scanButton }
        .sheet(item: Binding(get: { exportText.map { BLEExportItem(text: $0) } }, set: { if $0 == nil { exportText = nil } })) { item in
            BLEExportSheet(text: item.text)
        }
        .onAppear { scanner.rootAppeared() }
        .onDisappear { scanner.rootDisappeared() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { scanner.appBecameActive() } else { scanner.appBecameInactive() }
        }
    }

    // MARK: Sections

    private var modeSection: some View {
        Section {
            Toggle(isOn: Binding(get: { scanner.demoMode }, set: { scanner.setDemo($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) { Text("Demo mode").foregroundStyle(t.ink); Tag(style: .caution, text: "Demo") }
                    Text("Shows 5 sample devices so screens work without Bluetooth. Nothing is scanned.")
                        .font(.system(size: 13)).foregroundStyle(t.ink2)
                }
            }
            if scanner.authState == .poweredOn || scanner.demoMode {
                LabeledContent("Status") {
                    Text(statusText).foregroundStyle(t.ink2)
                }
                LabeledContent("Devices") { Text("\(scanner.peripherals.count)").monospacedDigit().foregroundStyle(t.ink2) }
            }
        } footer: {
            if scanner.demoMode { Text("Demo values are made up. They are labelled Demo everywhere and are never saved as real readings.") }
        }
        .rowCard()
    }

    private var statusText: String {
        if scanner.demoMode { return "Demo – not scanning" }
        return scanner.isScanning ? "Scanning" : "Stopped"
    }

    private var stateSection: some View {
        Section {
            switch scanner.authState {
            case .off:
                stateBlock(symbol: "antenna.radiowaves.left.and.right.slash", title: "Bluetooth is off",
                           text: "Turn Bluetooth on in Control Centre or Settings. Scanning starts by itself once it is on.", settings: false)
            case .unauthorized:
                stateBlock(symbol: "hand.raised", title: "Bluetooth permission denied",
                           text: "Assay was not allowed to use Bluetooth. Allow it in Settings to scan. Assay only scans while this screen is open.", settings: true)
            case .unsupported:
                stateBlock(symbol: "iphone.slash", title: "Bluetooth is not available here",
                           text: "This device or the iOS Simulator has no Bluetooth hardware. Turn on Demo mode above to see sample devices.", settings: false)
            default:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Starting Bluetooth…").foregroundStyle(t.ink2)
                }
            }
        }
        .rowCard()
    }

    private func stateBlock(symbol: String, title: String, text: String, settings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, hue: .peach)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
            }
            Text(text).font(.system(size: 14)).foregroundStyle(t.ink2)
            if settings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var deviceSections: some View {
        let all = filtered
        let pins = all.filter { scanner.isPinned($0.id) }
        let others = all.filter { !scanner.isPinned($0.id) }
        if all.isEmpty && (scanner.demoMode || scanner.authState == .poweredOn) {
            Section {
                if !query.isEmpty {
                    Text("Nothing matches “\(query)”.").foregroundStyle(t.ink2)
                } else if scanner.isScanning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning. Nothing heard yet. Move closer to a device that is switched on.").foregroundStyle(t.ink2)
                    }
                } else {
                    Text("No devices. Tap Start scan to look for nearby Bluetooth Low Energy devices.").foregroundStyle(t.ink2)
                }
            }.rowCard()
        }
        if !pins.isEmpty {
            Section("Pinned") { ForEach(pins) { row($0) } }.rowCard()
        }
        if !others.isEmpty {
            Section(pins.isEmpty ? "Nearby, strongest first" : "Nearby") { ForEach(others) { row($0) } }.rowCard()
        }
    }

    private var filtered: [BLEPeripheralInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = scanner.peripherals.filter { p in
            guard !q.isEmpty else { return true }
            if p.displayName.lowercased().contains(q) { return true }
            if p.id.uuidString.lowercased().contains(q) { return true }
            if p.serviceUUIDs.contains(where: { $0.lowercased().contains(q) || (BLEUUID.serviceName($0)?.lowercased().contains(q) ?? false) }) { return true }
            if let c = p.companyID, BLECompany.name(c)?.lowercased().contains(q) == true { return true }
            return false
        }
        return list.sorted { a, b in
            if a.smoothedRSSI != b.smoothedRSSI { return a.smoothedRSSI > b.smoothedRSSI }
            return a.id.uuidString < b.id.uuidString
        }
    }

    private func row(_ p: BLEPeripheralInfo) -> some View {
        NavigationLink {
            BLEDeviceView(scanner: scanner, deviceID: p.id)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: scanner.isPinned(p.id) ? "pin.fill" : "dot.radiowaves.left.and.right", hue: p.isDemo ? .butter : .sky)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(p.displayName).font(.system(size: 16, weight: .medium))
                            .foregroundStyle(p.name == nil ? t.ink2 : t.ink).lineLimit(1)
                        if p.isDemo { Tag(style: .caution, text: "Demo") }
                    }
                    Text(subtitle(p)).font(.system(size: 13)).foregroundStyle(t.ink2).lineLimit(1)
                }
                Spacer(minLength: 6)
                BLESignalTag(rssi: p.smoothedRSSI)
            }
        }
        .swipeActions(edge: .leading) {
            Button { scanner.togglePin(p.id) } label: { Label(scanner.isPinned(p.id) ? "Unpin" : "Pin", systemImage: scanner.isPinned(p.id) ? "pin.slash" : "pin") }
                .tint(t.accentColor)
        }
        .contextMenu {
            Button { scanner.togglePin(p.id) } label: { Label(scanner.isPinned(p.id) ? "Unpin" : "Pin", systemImage: scanner.isPinned(p.id) ? "pin.slash" : "pin") }
        }
    }

    private func subtitle(_ p: BLEPeripheralInfo) -> String {
        var parts: [String] = []
        if let g = p.guess { parts.append(g.label) }
        else if let c = p.companyID { parts.append(BLECompany.name(c) ?? "Unknown maker") }
        else if let s = p.serviceUUIDs.first { parts.append(BLEUUID.serviceName(s) ?? "Service \(BLEUUID.display(s))") }
        else { parts.append("No details advertised") }
        parts.append(p.connectable == false ? "not connectable" : (p.connectable == true ? "connectable" : "connectable: unknown"))
        return parts.joined(separator: " · ")
    }

    private var scanButton: some View {
        Button {
            if scanner.isScanning { scanner.stopScan(byUser: true) } else { scanner.startScan() }
        } label: {
            Text(scanner.isScanning ? "Stop scan" : "Start scan")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(scanner.demoMode || scanner.authState != .poweredOn && scanner.authState != .notStarted && scanner.authState != .unknown)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.bar)
    }

    private var companySection: some View {
        Section {
            DisclosureGroup("Company IDs Assay can name") {
                ForEach(BLECompany.table, id: \.id) { c in
                    LabeledContent(c.name) { Text(BLECompany.hex(c.id)).font(.system(size: 14, design: .monospaced)).foregroundStyle(t.ink2) }
                }
                Text("Only these six are built in. Any other company ID is shown as Unknown rather than guessed.")
                    .font(.system(size: 13)).foregroundStyle(t.ink2)
            }.foregroundStyle(t.ink)
        }.rowCard()
    }

    private var footerSection: some View {
        Section {
            Label("Scans only run while this screen is open. Leaving the screen or the app stops them.", systemImage: "eye")
            Label("Scanning with repeated adverts uses noticeably more battery. Stop the scan when you are done.", systemImage: "battery.50")
            Label("Assay does not track people or places. Nothing is uploaded, and nothing is kept except the UUIDs you pin on this phone.", systemImage: "hand.raised")
            Label("Background scanning is not supported in this version.", systemImage: "moon.zzz")
            Label("Signal strength (RSSI) is a rough guide to distance, not a measurement.", systemImage: "wave.3.right")
        }
        .font(.system(size: 13)).foregroundStyle(t.ink2)
        .rowCard()
    }
}

// MARK: - Export

struct BLEExportItem: Identifiable { let id = UUID(); let text: String }

struct BLEExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    let text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(t.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(ThemedBackground())
            .navigationTitle("Session log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: text, subject: Text("Assay Bluetooth session log")) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        }
    }
}

// MARK: - Signal tag: 4-step bar plus dBm in monospaced digits

struct BLESignalTag: View {
    @Environment(\.theme) private var t
    let rssi: Int

    /// Steps: 4 strong (-55 or higher), 3 good, 2 fair, 1 weak.
    static func steps(_ rssi: Int) -> Int {
        if rssi >= -55 { return 4 }
        if rssi >= -67 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
    static func word(_ steps: Int) -> String {
        switch steps { case 4: return "Strong"; case 3: return "Good"; case 2: return "Fair"; default: return "Weak" }
    }

    var body: some View {
        let s = Self.steps(rssi)
        HStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1..<5) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i <= s ? t.ink : t.ink3.opacity(0.45))
                        .frame(width: 3.5, height: CGFloat(3 + i * 3))
                }
            }
            .frame(height: 15, alignment: .bottom)
            Text("\(rssi) dBm").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(t.ink2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Signal \(Self.word(s)), \(rssi) decibel-milliwatts")
    }
}

// MARK: - Sparkline (plain Path, one stroke, no fill or gradient)

struct BLESparkline: View {
    @Environment(\.theme) private var t
    let values: [Int]
    var floor: Int = -100
    var ceiling: Int = -30

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: w, y: h))
                    p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(t.ink3.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                if values.count >= 2 {
                    Path { p in
                        let step = w / CGFloat(max(1, BLEPeripheralInfo.historyLimit - 1))
                        let startX = w - step * CGFloat(values.count - 1)
                        for (i, v) in values.enumerated() {
                            let c = min(max(v, floor), ceiling)
                            let y = h * (1 - CGFloat(c - floor) / CGFloat(ceiling - floor))
                            let pt = CGPoint(x: startX + step * CGFloat(i), y: y)
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }
                    .stroke(t.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 64)
        .overlay(alignment: .center) {
            if values.count < 2 { Text("Not enough samples yet").font(.system(size: 13)).foregroundStyle(t.ink3) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(values.isEmpty ? "No signal history yet" : "Signal history, \(values.count) samples, from \(values.min() ?? 0) to \(values.max() ?? 0) dBm")
    }
}
