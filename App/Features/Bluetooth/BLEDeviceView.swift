import SwiftUI

// MARK: - Device detail

struct BLEDeviceView: View {
    @Environment(\.theme) private var t
    let scanner: BLEScanner
    let deviceID: UUID
    @State private var writeTarget: BLECharacteristicInfo?

    private var device: BLEPeripheralInfo? { scanner.peripheral(deviceID) }
    private var isConnected: Bool { scanner.connectedID == deviceID }

    var body: some View {
        List {
            if let d = device {
                summarySection(d)
                advertisedSection(d)
                signalSection(d)
                guessSection(d)
                gattSection(d)
                if isConnected, !scanner.readings.filter({ $0.deviceID == deviceID }).isEmpty { historySection }
            } else {
                Section {
                    ContentUnavailableView("Device not found", systemImage: "questionmark.circle",
                                           description: Text("It has not been heard recently. Go back and scan again."))
                }.listRowBackground(Color.clear)
            }
        }
        .themedList()
        .navigationTitle(device?.displayName ?? "Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { scanner.togglePin(deviceID) } label: {
                    Label(scanner.isPinned(deviceID) ? "Unpin" : "Pin", systemImage: scanner.isPinned(deviceID) ? "pin.fill" : "pin")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { connectBar }
        .sheet(item: $writeTarget) { c in
            BLEWriteSheet(scanner: scanner, characteristic: c)
        }
        .onAppear { scanner.detailAppeared(deviceID) }
        .onDisappear { scanner.detailDisappeared(deviceID) }
    }

    // MARK: Sections

    private func summarySection(_ d: BLEPeripheralInfo) -> some View {
        Section {
            HStack {
                Text("Signal").foregroundStyle(t.ink)
                Spacer()
                BLESignalTag(rssi: d.smoothedRSSI)
                evidence(d.isDemo)
            }
            LabeledContent("Last seen") {
                if d.isDemo { Text("Demo").foregroundStyle(t.ink2) } else { Text(d.lastSeen, style: .relative).foregroundStyle(t.ink2) }
            }
            LabeledContent("Peripheral UUID") {
                Text(d.id.uuidString).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2).textSelection(.enabled)
            }
        } footer: {
            Text("This UUID is assigned by iOS and is only meaningful on this phone.")
        }.rowCard()
    }

    private func advertisedSection(_ d: BLEPeripheralInfo) -> some View {
        Section("Advertised data") {
            factRow("Name", d.name ?? "Unnamed", d.isDemo, observed: d.name != nil)
            factRow("Connectable", d.connectable.map { $0 ? "Yes" : "No" } ?? "Not advertised", d.isDemo, observed: d.connectable != nil)
            factRow("Tx power", d.txPower.map { "\($0) dBm" } ?? "Not advertised", d.isDemo, observed: d.txPower != nil)
            if d.serviceUUIDs.isEmpty {
                factRow("Services", "None advertised", d.isDemo, observed: false)
            } else {
                ForEach(d.serviceUUIDs, id: \.self) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(BLEUUID.serviceName(s) ?? "Unknown").foregroundStyle(t.ink)
                            Text(BLEUUID.display(s)).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                        }
                        Spacer()
                        if d.isDemo { Tag(style: .caution, text: "Demo") }
                        Tag(style: BLEUUID.serviceName(s) == nil ? .unknown : .observed)
                    }
                }
            }
            if let m = d.manufacturerData {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Manufacturer data").foregroundStyle(t.ink)
                        Spacer()
                        if d.isDemo { Tag(style: .caution, text: "Demo") }
                        Tag(style: .observed)
                    }
                    Text(BLEHex.string(m)).font(.system(size: 13, design: .monospaced)).foregroundStyle(t.ink2).textSelection(.enabled)
                }
                if let cid = d.companyID {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Company").foregroundStyle(t.ink)
                            Text(BLECompany.hex(cid)).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                        }
                        Spacer()
                        Text(BLECompany.name(cid) ?? "Not in Assay's list").foregroundStyle(t.ink2)
                        Tag(style: BLECompany.name(cid) == nil ? .unknown : .observed)
                    }
                }
            } else {
                factRow("Manufacturer data", "None advertised", d.isDemo, observed: false)
            }
        }.rowCard()
    }

    private func factRow(_ label: String, _ value: String, _ demo: Bool, observed: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(t.ink)
            Spacer()
            Text(value).foregroundStyle(t.ink2).multilineTextAlignment(.trailing)
            if demo { Tag(style: .caution, text: "Demo") }
            Tag(style: observed ? .observed : .unknown, text: observed ? nil : "Not available")
        }
    }

    @ViewBuilder private func evidence(_ demo: Bool) -> some View {
        if demo { Tag(style: .caution, text: "Demo") }
        Tag(style: .observed)
    }

    private func signalSection(_ d: BLEPeripheralInfo) -> some View {
        Section {
            BLESparkline(values: d.history).padding(.vertical, 4)
            HStack {
                Text("Last 60 samples, one per second at most").font(.system(size: 12)).foregroundStyle(t.ink3)
                Spacer()
                Text("−30 to −100 dBm").font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink3)
            }
            if let lo = d.history.min(), let hi = d.history.max() {
                LabeledContent("Range") { Text("\(lo) to \(hi) dBm").font(.system(size: 14, design: .monospaced)).foregroundStyle(t.ink2) }
            }
        } header: {
            HStack(spacing: 6) { Text("Signal history"); if d.isDemo { Tag(style: .caution, text: "Demo") } }
        } footer: {
            Text("Smoothed to reduce jumping. Walls, bodies and the phone's orientation change RSSI a lot, so treat it as a rough guide.")
        }.rowCard()
    }

    @ViewBuilder private func guessSection(_ d: BLEPeripheralInfo) -> some View {
        Section("Guessed device type") {
            if let g = d.guess {
                HStack {
                    Text(g.label).foregroundStyle(t.ink)
                    Spacer()
                    Tag(style: .inferred(g.confidence))
                }
                Text("Based only on the advertised service UUIDs and company ID. The device has not said what it is.")
                    .font(.system(size: 13)).foregroundStyle(t.ink2)
            } else {
                HStack {
                    Text("No guess").foregroundStyle(t.ink)
                    Spacer()
                    Tag(style: .unknown)
                }
                Text("Nothing in the advert is specific enough to guess from.").font(.system(size: 13)).foregroundStyle(t.ink2)
            }
        }.rowCard()
    }

    // MARK: Connection and GATT

    @ViewBuilder private func gattSection(_ d: BLEPeripheralInfo) -> some View {
        if isConnected || d.connectable != nil {
            Section {
                connectionStatus(d)
                if isConnected {
                    ForEach(scanner.services) { s in serviceBlock(s) }
                }
            } header: {
                Text("Services and characteristics")
            } footer: {
                Text(isConnected ? "Reading is safe: it only asks the device for a value. Writing is separate and always asks first."
                                 : "Connecting is optional and only happens when you tap the button below. The connection closes when you leave this screen.")
            }.rowCard()
        }
    }

    @ViewBuilder private func connectionStatus(_ d: BLEPeripheralInfo) -> some View {
        if !isConnected {
            if d.connectable == false {
                Label("This device says it is not connectable.", systemImage: "nosign").foregroundStyle(t.ink2)
            } else {
                Label("Not connected.", systemImage: "link.badge.plus").foregroundStyle(t.ink2)
            }
        } else {
            switch scanner.connection {
            case .idle: Label("Not connected.", systemImage: "link").foregroundStyle(t.ink2)
            case .connecting: HStack(spacing: 12) { ProgressView(); Text("Connecting…").foregroundStyle(t.ink2) }
            case .discovering: HStack(spacing: 12) { ProgressView(); Text("Discovering services…").foregroundStyle(t.ink2) }
            case .ready:
                HStack {
                    Label(scanner.services.isEmpty ? "Connected. The device lists no services." : "Connected", systemImage: "link").foregroundStyle(t.ink)
                    Spacer()
                    if d.isDemo { Tag(style: .caution, text: "Demo") }
                }
            case .failed(let m): Label(m, systemImage: "exclamationmark.triangle").foregroundStyle(t.ink)
            case .disconnected(let m): Label("Disconnected" + (m.map { ": " + $0 } ?? "."), systemImage: "link.badge.minus").foregroundStyle(t.ink)
            }
        }
    }

    @ViewBuilder private func serviceBlock(_ s: BLEServiceInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name ?? "Unknown").font(.system(size: 16, weight: .semibold)).foregroundStyle(t.ink)
                Text("Service " + BLEUUID.display(s.uuid)).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
            }
            Spacer()
            if s.isDemo { Tag(style: .caution, text: "Demo") }
            Tag(style: s.name == nil ? .unknown : .observed, text: s.name == nil ? "Unknown" : "Known")
        }
        ForEach(s.characteristics) { c in characteristicBlock(c) }
    }

    @ViewBuilder private func characteristicBlock(_ c: BLECharacteristicInfo) -> some View {
        let history = scanner.readings(for: c.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name ?? "Unknown").font(.system(size: 15, weight: .medium)).foregroundStyle(t.ink)
                    Text(BLEUUID.display(c.uuid)).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                }
                Spacer()
                if c.isDemo { Tag(style: .caution, text: "Demo") }
                if c.name == nil { Tag(style: .unknown) }
            }
            Text(c.properties.labels.isEmpty ? "No properties listed" : c.properties.labels.joined(separator: " · "))
                .font(.system(size: 13)).foregroundStyle(t.ink2)
            if !c.descriptors.isEmpty {
                Text("Descriptors: " + c.descriptors.map { ($0.name ?? "Unknown") + " (" + BLEUUID.display($0.uuid) + ")" }.joined(separator: ", "))
                    .font(.system(size: 12)).foregroundStyle(t.ink3)
            }
            HStack(spacing: 10) {
                if c.properties.read {
                    Button("Read") { scanner.read(c.id) }.buttonStyle(.bordered).controlSize(.small)
                }
                if c.properties.canWrite {
                    Button("Write…") { writeTarget = c }.buttonStyle(.bordered).controlSize(.small)
                }
                if c.properties.notify || c.properties.indicate {
                    Text("Notifications are not subscribed in this version.").font(.system(size: 12)).foregroundStyle(t.ink3)
                }
            }
            if let err = scanner.readErrors[c.id] {
                Label(err, systemImage: "exclamationmark.triangle").font(.system(size: 13)).foregroundStyle(t.ink)
            }
            if let latest = history.first {
                valueView(latest)
                if history.count > 1 {
                    DisclosureGroup("Earlier values (\(history.count - 1))") {
                        ForEach(history.dropFirst()) { r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.date, style: .time).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink3)
                                Text(r.hex).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2)
                            }
                        }
                    }.font(.system(size: 13)).foregroundStyle(t.ink2)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func valueView(_ r: BLEReading) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(r.date, format: .dateTime.hour().minute().second()).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink3)
                if r.isDemo { Tag(style: .caution, text: "Demo") }
                Tag(style: .observed, text: r.isDemo ? "Sample" : "Read")
            }
            valueLine("Hex", r.hex, mono: true)
            valueLine("Text", r.text.map { "“\($0)”" } ?? "Not text", mono: false)
            valueLine("Number", r.number.map { $0 + " (little-endian, unsigned)" } ?? "Not a 1, 2, 4 or 8 byte value", mono: false)
            if let m = r.meaning { valueLine("Meaning", m, mono: false) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func valueLine(_ k: String, _ v: String, mono: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(k).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.ink3).frame(width: 52, alignment: .leading)
            Text(v).font(.system(size: 13, design: mono ? .monospaced : .default)).foregroundStyle(t.ink).textSelection(.enabled)
        }
    }

    private var historySection: some View {
        Section("Values read this session") {
            ForEach(scanner.readings.filter { $0.deviceID == deviceID }.prefix(30)) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BLEUUID.characteristicName(r.charUUID) ?? "Unknown (\(BLEUUID.display(r.charUUID)))").foregroundStyle(t.ink)
                        Text(r.hex).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink2).lineLimit(1)
                    }
                    Spacer()
                    if r.isDemo { Tag(style: .caution, text: "Demo") }
                    Text(r.date, format: .dateTime.hour().minute().second()).font(.system(size: 12, design: .monospaced)).foregroundStyle(t.ink3)
                }
            }
        }.rowCard()
    }

    // MARK: Pinned action

    @ViewBuilder private var connectBar: some View {
        if let d = device {
            Button {
                if isConnected { scanner.disconnect() } else { scanner.connect(deviceID) }
            } label: {
                Text(isConnected ? "Disconnect" : "Connect and read services")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isConnected && d.connectable == false)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(.bar)
        }
    }
}

// MARK: - Write sheet (the only place a write can start)

struct BLEWriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    let scanner: BLEScanner
    let characteristic: BLECharacteristicInfo

    @State private var format: BLEWriteFormat = .hex
    @State private var width: BLEWriteWidth = .one
    @State private var input = ""
    @State private var confirmed = false
    @State private var sent = false

    private var result: Result<Data, BLEInputError> { BLEWritePayload.bytes(format: format, input: input, width: width) }
    private var bytes: Data? { if case .success(let d) = result { return d } else { return nil } }
    private var canSend: Bool { characteristic.properties.canWrite && confirmed && bytes != nil && !sent }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Writing changes something on the other device. Assay cannot tell what a value does. Only write values you understand.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(t.ink)
                    LabeledContent("Characteristic") { Text((characteristic.name ?? "Unknown") + " · " + BLEUUID.display(characteristic.uuid)).foregroundStyle(t.ink2) }
                    LabeledContent("Method") {
                        Text(characteristic.properties.write ? "Write with response" : (characteristic.properties.writeNoResponse ? "Write without response" : "Not supported"))
                            .foregroundStyle(t.ink2)
                    }
                    if characteristic.isDemo { HStack { Text("Demo device: nothing is sent").foregroundStyle(t.ink); Spacer(); Tag(style: .caution, text: "Demo") } }
                }.rowCard()

                if !characteristic.properties.canWrite {
                    Section { Text("This characteristic does not support writing, so the controls are switched off.").foregroundStyle(t.ink2) }.rowCard()
                }

                Section("Value") {
                    Picker("Format", selection: $format) { ForEach(BLEWriteFormat.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    TextField(placeholder, text: $input)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(format == .number ? .numbersAndPunctuation : .default)
                        .font(.system(size: 16, design: .monospaced))
                    if format == .number {
                        Picker("Size", selection: $width) { ForEach(BLEWriteWidth.allCases) { Text($0.label).tag($0) } }
                        Text("Sent little-endian.").font(.system(size: 13)).foregroundStyle(t.ink2)
                    }
                }.rowCard().disabled(!characteristic.properties.canWrite)

                Section("Bytes that will be sent") {
                    switch result {
                    case .success(let d):
                        Text(BLEHex.string(d)).font(.system(size: 15, design: .monospaced)).foregroundStyle(t.ink).textSelection(.enabled)
                        Text("\(d.count) byte\(d.count == 1 ? "" : "s")").font(.system(size: 13)).foregroundStyle(t.ink2)
                    case .failure(let e):
                        Text(input.isEmpty ? "Nothing to send yet." : e.text).foregroundStyle(t.ink2)
                    }
                }.rowCard()

                Section {
                    Toggle("I understand and want to send these bytes", isOn: $confirmed)
                        .foregroundStyle(t.ink)
                        .disabled(!characteristic.properties.canWrite)
                    Button { send() } label: { Text(sent ? "Sent" : "Send") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSend)
                        .listRowBackground(Color.clear).listRowInsets(.init())
                }.rowCard()
            }
            .themedList()
            .navigationTitle("Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() } } }
            .onChange(of: input) { _, _ in confirmed = false; sent = false }
            .onChange(of: format) { _, _ in confirmed = false; sent = false }
            .onChange(of: width) { _, _ in confirmed = false; sent = false }
        }
    }

    private var placeholder: String {
        switch format { case .text: return "Text"; case .hex: return "01 FF 2A"; case .number: return "42" }
    }

    private func send() {
        guard canSend, let d = bytes else { return }
        scanner.write(characteristic.id, data: d)
        sent = true
        confirmed = false
        Haptics.success()
    }
}
