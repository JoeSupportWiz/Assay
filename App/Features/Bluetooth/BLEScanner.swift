import SwiftUI
import Foundation
import CoreBluetooth

enum BLEAuthState: Equatable {
    case notStarted, poweredOn, off, unauthorized, unsupported, resetting, unknown
}

enum BLEConnectionState: Equatable {
    case idle
    case connecting
    case discovering
    case ready
    case failed(String)
    case disconnected(String?)
}

/// Wraps CBCentralManager. Observation is throttled: raw adverts go into `table` (not observed) and are
/// copied to `peripherals` at most twice a second, so SwiftUI is not asked to re-render for every advert.
@MainActor
@Observable
final class BLEScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: Observed state (what the UI reads)
    private(set) var authState: BLEAuthState = .notStarted
    private(set) var isScanning = false
    private(set) var peripherals: [BLEPeripheralInfo] = []
    private(set) var pinned: Set<UUID> = []
    private(set) var connectedID: UUID?
    private(set) var connection: BLEConnectionState = .idle
    private(set) var services: [BLEServiceInfo] = []
    private(set) var readings: [BLEReading] = []
    private(set) var readErrors: [String: String] = [:]
    private(set) var events: [BLEEvent] = []
    private(set) var sessionStart = Date()
    var demoMode = false

    // MARK: Internals (not observed)
    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var table: [UUID: BLEPeripheralInfo] = [:]
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var cbPeripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var cbChars: [String: CBCharacteristic] = [:]
    @ObservationIgnored private var pendingDiscovery = 0
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    @ObservationIgnored private var userPaused = false
    @ObservationIgnored private var rootVisible = false
    @ObservationIgnored private var openDetails: Set<UUID> = []
    @ObservationIgnored private var demoValues: [String: Data] = [:]

    private static let pinKey = "assay.ble.pinned"
    private static let flushInterval: Duration = .milliseconds(500)   // about 2 updates a second
    private static let maxDevices = 400
    private static let maxEvents = 600
    private static let maxReadings = 300
    private static let connectTimeout: Duration = .seconds(15)

    override init() {
        super.init()
        let saved = UserDefaults.standard.stringArray(forKey: Self.pinKey) ?? []
        pinned = Set(saved.compactMap { UUID(uuidString: $0) })
    }

    // MARK: Screen lifecycle

    func rootAppeared() {
        rootVisible = true
        if demoMode { return }
        if !userPaused { startScan() }
    }

    func rootDisappeared() {
        rootVisible = false
        scheduleKeepAliveCheck()
    }

    func detailAppeared(_ id: UUID) { openDetails.insert(id) }

    /// Closing a device screen always drops its connection, so nothing stays connected in the background.
    func detailDisappeared(_ id: UUID) {
        openDetails.remove(id)
        if connectedID == id { disconnect() }
        scheduleKeepAliveCheck()
    }

    /// Pushing a detail screen makes the list disappear for a moment, so wait before deciding the user has left.
    private func scheduleKeepAliveCheck() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self else { return }
            if !self.rootVisible && self.openDetails.isEmpty {
                self.stopScan()
                self.disconnect()
            }
        }
    }

    /// Called when the app leaves the foreground. Background scanning is not supported in this version.
    func appBecameInactive() {
        stopScan()
        disconnect()
    }

    func appBecameActive() {
        if rootVisible && !demoMode && !userPaused { startScan() }
    }

    // MARK: Demo

    func setDemo(_ on: Bool) {
        demoMode = on
        if on {
            stopScan()
            disconnect()
            let now = Date()
            table = [:]
            for d in BLEDemo.devices(now: now) { table[d.id] = d }
            peripherals = Array(table.values)
            log("Demo mode on. Sample devices only; nothing here was received over Bluetooth.", device: nil, demo: true)
        } else {
            disconnect()
            table = [:]
            peripherals = []
            log("Demo mode off.", device: nil, demo: false)
            if rootVisible && !userPaused { startScan() }
        }
    }

    // MARK: Scanning

    private func ensureCentral() {
        guard central == nil else { return }
        // Creating the manager is what triggers the system permission prompt, so it only happens when the user opens this screen.
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        refreshAuthState()
    }

    func startScan() {
        userPaused = false
        if demoMode { return }
        ensureCentral()
        guard let central else { return }
        refreshAuthState()
        guard central.state == .poweredOn else { return }
        if central.isScanning { isScanning = true; startFlushing(); return }
        // Duplicates are allowed so RSSI keeps updating; this is the main battery cost.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        startFlushing()
        log("Scan started.", device: nil, demo: false)
    }

    /// Stops scanning. `byUser` keeps it stopped when the screen is shown again.
    func stopScan(byUser: Bool = false) {
        if byUser { userPaused = true }
        if let central, central.isScanning { central.stopScan() }
        if isScanning { log(byUser ? "Scan stopped by the user." : "Scan stopped (screen closed or app left the foreground).", device: nil, demo: false) }
        isScanning = false
        flush()
        flushTask?.cancel()
        flushTask = nil
    }

    private func refreshAuthState() {
        guard let central else { authState = .notStarted; return }
        switch central.state {
        case .poweredOn: authState = .poweredOn
        case .poweredOff: authState = .off
        case .unauthorized: authState = .unauthorized
        case .unsupported: authState = .unsupported
        case .resetting: authState = .resetting
        case .unknown: authState = .unknown
        @unknown default: authState = .unknown
        }
    }

    private func startFlushing() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: BLEScanner.flushInterval)
                guard let self, !Task.isCancelled else { return }
                self.flush()
            }
        }
    }

    private func flush() {
        guard dirty else { return }
        dirty = false
        let now = Date()
        // Forget devices not heard for two minutes, unless pinned or connected.
        for (id, p) in table where !p.isDemo && now.timeIntervalSince(p.lastSeen) > 120 && !pinned.contains(id) && id != connectedID {
            table[id] = nil
        }
        peripherals = Array(table.values)
    }

    // MARK: Pins

    func isPinned(_ id: UUID) -> Bool { pinned.contains(id) }

    func togglePin(_ id: UUID) {
        if pinned.contains(id) { pinned.remove(id) } else { pinned.insert(id) }
        UserDefaults.standard.set(pinned.map { $0.uuidString }.sorted(), forKey: Self.pinKey)
    }

    func peripheral(_ id: UUID) -> BLEPeripheralInfo? {
        peripherals.first { $0.id == id } ?? table[id]
    }

    // MARK: Connect and read services (only ever from an explicit tap)

    func connect(_ id: UUID) {
        if connectedID != nil && connectedID != id { disconnect() }
        services = []
        cbChars = [:]
        readErrors = [:]
        let name = peripheral(id)?.displayName ?? "device"

        if BLEDemo.isDemoID(id) {
            let g = BLEDemo.gatt(for: id, name: name)
            connectedID = id
            demoValues = g.values
            services = g.services
            connection = .ready
            log("Demo: opened sample services for \(name). No real connection was made.", device: id, demo: true)
            return
        }

        guard let p = cbPeripherals[id] else {
            connection = .failed("This device is no longer in range. Scan again, then retry.")
            return
        }
        connectedID = id
        connection = .connecting
        p.delegate = self
        central?.connect(p, options: nil)
        log("Connecting to \(name)…", device: id, demo: false)
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            try? await Task.sleep(for: BLEScanner.connectTimeout)
            guard let self, !Task.isCancelled else { return }
            if self.connection == .connecting || self.connection == .discovering {
                self.log("Connection timed out after 15 seconds.", device: id, demo: false)
                if let p = self.cbPeripherals[id] { self.central?.cancelPeripheralConnection(p) }
                self.connection = .failed("Timed out after 15 seconds. The device may not accept connections, or may already be connected elsewhere.")
            }
        }
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        if let id = connectedID {
            if let p = cbPeripherals[id], !BLEDemo.isDemoID(id) { central?.cancelPeripheralConnection(p) }
            log("Disconnected.", device: id, demo: BLEDemo.isDemoID(id))
        }
        connectedID = nil
        if connection != .idle { connection = .idle }
        services = []
        cbChars = [:]
        demoValues = [:]
    }

    func read(_ charID: String) {
        guard let id = connectedID else { return }
        readErrors[charID] = nil
        if BLEDemo.isDemoID(id) {
            guard let data = demoValues[charID], let (s, c) = Self.split(charID) else {
                readErrors[charID] = "Demo device has no sample value for this."
                return
            }
            addReading(BLEReading(date: Date(), deviceID: id, charID: charID, serviceUUID: s, charUUID: c, data: data, isDemo: true))
            return
        }
        guard let ch = cbChars[charID], let p = cbPeripherals[id] else {
            readErrors[charID] = "Not available. Reconnect and try again."
            return
        }
        p.readValue(for: ch)
    }

    /// Writes bytes. The UI only calls this after an explicit confirmation; this also refuses if the characteristic can't be written.
    func write(_ charID: String, data: Data) {
        guard let id = connectedID,
              let info = services.flatMap({ $0.characteristics }).first(where: { $0.id == charID }),
              info.properties.canWrite else {
            readErrors[charID] = "This characteristic does not support writing."
            return
        }
        guard !data.isEmpty, data.count <= BLEWritePayload.maxBytes else { return }
        let hex = BLEHex.string(data)
        if BLEDemo.isDemoID(id) {
            demoValues[charID] = data
            log("Demo write to \(BLEUUID.display(info.uuid)): \(hex). Nothing was sent.", device: id, demo: true)
            return
        }
        guard let ch = cbChars[charID], let p = cbPeripherals[id] else {
            readErrors[charID] = "Not available. Reconnect and try again."
            return
        }
        let type: CBCharacteristicWriteType = info.properties.write ? .withResponse : .withoutResponse
        p.writeValue(data, for: ch, type: type)
        log("Write to \(BLEUUID.display(info.uuid)) (\(data.count) bytes): \(hex)", device: id, demo: false)
        if type == .withoutResponse { log("Write without response sent; the device does not confirm it.", device: id, demo: false) }
    }

    private func addReading(_ r: BLEReading) {
        readings.insert(r, at: 0)
        if readings.count > Self.maxReadings { readings.removeLast(readings.count - Self.maxReadings) }
        log("Read \(BLEUUID.display(r.charUUID)) in \(BLEUUID.display(r.serviceUUID)): \(r.hex)", device: r.deviceID, demo: r.isDemo)
    }

    func readings(for charID: String) -> [BLEReading] { readings.filter { $0.charID == charID } }

    private static func split(_ charID: String) -> (String, String)? {
        let parts = charID.components(separatedBy: "|")
        guard parts.count >= 3 else { return nil }
        return (parts[1], parts[2])
    }

    // MARK: Log

    private func log(_ message: String, device: UUID?, demo: Bool) {
        events.append(BLEEvent(date: Date(), deviceID: device, message: message, isDemo: demo))
        if events.count > Self.maxEvents { events.removeFirst(events.count - Self.maxEvents) }
    }

    /// Plain-text session log. Contains peripheral names and UUIDs as seen over the air or in GATT, and nothing about the user.
    func sessionLog() -> String {
        let iso = ISO8601DateFormatter()
        var out: [String] = []
        out.append("Assay Bluetooth notebook – session log")
        out.append("Started: \(iso.string(from: sessionStart))")
        out.append("Exported: \(iso.string(from: Date()))")
        out.append(demoMode ? "Mode: DEMO – devices below are sample data, not real Bluetooth devices" : "Mode: live scan")
        out.append("Peripheral UUIDs are iOS-assigned identifiers for this phone only. No other identifiers are included.")
        out.append("")
        out.append("== Devices (\(peripherals.count)) ==")
        for p in peripherals.sorted(by: { $0.rssi > $1.rssi }) {
            out.append("")
            out.append("\(p.displayName)\(p.isDemo ? " [Demo]" : "")")
            out.append("  UUID: \(p.id.uuidString)")
            out.append("  RSSI (smoothed): \(p.smoothedRSSI) dBm [Observed]")
            out.append("  Last seen: \(iso.string(from: p.lastSeen))")
            out.append("  Connectable: \(p.connectable.map { $0 ? "yes" : "no" } ?? "not advertised")")
            out.append("  Tx power: \(p.txPower.map { "\($0) dBm" } ?? "not advertised")")
            out.append("  Services advertised: \(p.serviceUUIDs.isEmpty ? "none" : p.serviceUUIDs.map { BLEUUID.display($0) + (BLEUUID.serviceName($0).map { " (\($0))" } ?? " (Unknown)") }.joined(separator: ", "))")
            if let m = p.manufacturerData {
                let cid = BLECompany.id(from: m)
                let cname = cid.flatMap { BLECompany.name($0) } ?? "Unknown"
                out.append("  Manufacturer data: \(BLEHex.string(m)) [Observed]")
                if let cid { out.append("  Company ID: \(BLECompany.hex(cid)) = \(cname)") }
            } else {
                out.append("  Manufacturer data: none")
            }
            if let g = p.guess { out.append("  Guessed type: \(g.label) [Inferred, \(g.confidence)%]") }
        }
        out.append("")
        out.append("== Values read ==")
        if readings.isEmpty { out.append("None.") }
        for r in readings.reversed() {
            var line = "\(iso.string(from: r.date))  device \(r.deviceID.uuidString)  service \(BLEUUID.display(r.serviceUUID))  characteristic \(BLEUUID.display(r.charUUID))\(BLEUUID.characteristicName(r.charUUID).map { " (\($0))" } ?? " (Unknown)")  hex \(r.hex)"
            if let t = r.text { line += "  text \"\(t)\"" }
            if let n = r.number { line += "  number \(n)" }
            if r.isDemo { line += "  [Demo]" }
            out.append(line)
        }
        out.append("")
        out.append("== Events ==")
        for e in events {
            out.append("\(iso.string(from: e.date))  \(e.deviceID.map { $0.uuidString + "  " } ?? "")\(e.message)\(e.isDemo ? " [Demo]" : "")")
        }
        return out.joined(separator: "\n")
    }

    // MARK: GATT mapping

    private func rebuildServices(for p: CBPeripheral) {
        let did = p.identifier
        var infos: [BLEServiceInfo] = []
        var map: [String: CBCharacteristic] = [:]
        for s in p.services ?? [] {
            let su = BLEUUID.normalise(s.uuid.uuidString)
            var chars: [BLECharacteristicInfo] = []
            for (i, c) in (s.characteristics ?? []).enumerated() {
                let cu = BLEUUID.normalise(c.uuid.uuidString)
                let cid = "\(did.uuidString)|\(su)|\(cu)|\(i)"
                var props = BLECharacteristicProperties()
                let f = c.properties
                props.read = f.contains(.read)
                props.write = f.contains(.write)
                props.writeNoResponse = f.contains(.writeWithoutResponse)
                props.notify = f.contains(.notify)
                props.indicate = f.contains(.indicate)
                if f.contains(.broadcast) { props.other.append("Broadcast") }
                if f.contains(.authenticatedSignedWrites) { props.other.append("Signed write") }
                if f.contains(.extendedProperties) { props.other.append("Extended") }
                let descs = (c.descriptors ?? []).enumerated().map { (j, d) in
                    BLEDescriptorInfo(id: cid + "|\(j)", uuid: BLEUUID.normalise(d.uuid.uuidString))
                }
                chars.append(BLECharacteristicInfo(id: cid, uuid: cu, properties: props, descriptors: descs))
                map[cid] = c
            }
            infos.append(BLEServiceInfo(id: "\(did.uuidString)|\(su)", uuid: su, characteristics: chars))
        }
        services = infos
        cbChars = map
    }

    private func finishDiscoveryIfDone() {
        if pendingDiscovery <= 0 && connection == .discovering {
            connection = .ready
            connectTask?.cancel()
            log("Discovered \(services.count) services, \(services.reduce(0) { $0 + $1.characteristics.count }) characteristics.", device: connectedID, demo: false)
        }
    }

    // MARK: CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            self.refreshAuthState()
            if central.state == .poweredOn {
                if self.rootVisible && !self.userPaused && !self.demoMode { self.startScan() }
            } else {
                self.isScanning = false
                self.flushTask?.cancel()
                self.flushTask = nil
                if self.connectedID != nil && !BLEDemo.isDemoID(self.connectedID!) { self.connection = .disconnected("Bluetooth became unavailable.") }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let svc = ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []).map { BLEUUID.normalise($0.uuidString) }
        let mfr = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let tx = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let conn = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            guard !self.demoMode else { return }
            let now = Date()
            let id = peripheral.identifier
            self.cbPeripherals[id] = peripheral
            if var existing = self.table[id] {
                existing.absorb(name: name, rssi: rssi, services: svc, manufacturer: mfr, tx: tx, connectable: conn, now: now)
                self.table[id] = existing
            } else if self.table.count < Self.maxDevices {
                self.table[id] = BLEPeripheralInfo.first(id: id, name: name, rssi: rssi, services: svc, manufacturer: mfr,
                                                         tx: tx, connectable: conn, now: now)
            }
            self.dirty = true
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            self.connection = .discovering
            self.pendingDiscovery = 1
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let text = error?.localizedDescription ?? "The connection failed."
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            self.connectTask?.cancel()
            self.connection = .failed(text)
            self.log("Connection failed: \(text)", device: peripheral.identifier, demo: false)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let text = error?.localizedDescription
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            if self.connection != .idle {
                self.connection = .disconnected(text)
                self.log("Disconnected\(text.map { ": " + $0 } ?? ".")", device: peripheral.identifier, demo: false)
            }
        }
    }

    // MARK: CBPeripheralDelegate

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let text = error?.localizedDescription
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            if let text { self.connection = .failed(text); return }
            let list = peripheral.services ?? []
            self.pendingDiscovery = list.count
            self.rebuildServices(for: peripheral)
            for s in list { peripheral.discoverCharacteristics(nil, for: s) }
            self.finishDiscoveryIfDone()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            self.pendingDiscovery -= 1
            let chars = service.characteristics ?? []
            self.pendingDiscovery += chars.count
            for c in chars { peripheral.discoverDescriptors(for: c) }
            self.rebuildServices(for: peripheral)
            self.finishDiscoveryIfDone()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier else { return }
            self.pendingDiscovery -= 1
            self.rebuildServices(for: peripheral)
            self.finishDiscoveryIfDone()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = characteristic.value
        let text = error?.localizedDescription
        MainActor.assumeIsolated {
            guard self.connectedID == peripheral.identifier,
                  let entry = self.cbChars.first(where: { $0.value === characteristic }) else { return }
            if let text {
                self.readErrors[entry.key] = text
                self.log("Read failed for \(BLEUUID.display(BLEUUID.normalise(characteristic.uuid.uuidString))): \(text)", device: peripheral.identifier, demo: false)
                return
            }
            guard let data, let (s, c) = Self.split(entry.key) else { return }
            self.addReading(BLEReading(date: Date(), deviceID: peripheral.identifier, charID: entry.key,
                                       serviceUUID: s, charUUID: c, data: data, isDemo: false))
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let text = error?.localizedDescription
        MainActor.assumeIsolated {
            let u = BLEUUID.display(BLEUUID.normalise(characteristic.uuid.uuidString))
            if let text {
                if let entry = self.cbChars.first(where: { $0.value === characteristic }) { self.readErrors[entry.key] = "Write failed: " + text }
                self.log("Write to \(u) failed: \(text)", device: peripheral.identifier, demo: false)
            } else {
                self.log("Write to \(u) acknowledged by the device.", device: peripheral.identifier, demo: false)
            }
        }
    }
}
