import SwiftUI
import Foundation

// MARK: - Value types (no CoreBluetooth objects in here, so they are cheap to copy and easy to test)

struct BLEDeviceRoute: Hashable { let id: UUID }

struct BLEPeripheralInfo: Identifiable, Equatable {
    let id: UUID
    var name: String?
    /// Exponentially smoothed RSSI in dBm. The raw value jumps around by 10 dB or more between adverts.
    var rssi: Double
    var lastRawRSSI: Int
    /// At most one sample per second, newest last, capped at `BLEPeripheralInfo.historyLimit`.
    var history: [Int] = []
    var lastHistoryAt: Date
    var serviceUUIDs: [String] = []
    var manufacturerData: Data?
    var txPower: Int?
    var connectable: Bool?
    var firstSeen: Date
    var lastSeen: Date
    var isDemo = false

    static let historyLimit = 60

    var displayName: String {
        if let n = name, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Unnamed"
    }
    var smoothedRSSI: Int { Int(rssi.rounded()) }
    var companyID: UInt16? { BLECompany.id(from: manufacturerData) }
    var guess: BLEGuess? { BLEGuess.make(services: serviceUUIDs, companyID: companyID) }

    /// Folds one advertisement into this record. Fields the advert did not carry are left as they were,
    /// because a scan response and the main advert often arrive separately.
    mutating func absorb(name newName: String?, rssi raw: Int, services: [String], manufacturer: Data?,
                         tx: Int?, connectable newConnectable: Bool?, now: Date) {
        if let newName, !newName.isEmpty { name = newName }
        if raw != 127 && raw < 0 {          // 127 means "not available" in CoreBluetooth
            lastRawRSSI = raw
            rssi = rssi * 0.7 + Double(raw) * 0.3
            if now.timeIntervalSince(lastHistoryAt) >= 1.0 || history.isEmpty {
                history.append(Int(rssi.rounded()))
                if history.count > Self.historyLimit { history.removeFirst(history.count - Self.historyLimit) }
                lastHistoryAt = now
            }
        }
        for s in services where !serviceUUIDs.contains(s) { serviceUUIDs.append(s) }
        if let manufacturer { manufacturerData = manufacturer }
        if let tx { txPower = tx }
        if let newConnectable { connectable = newConnectable }
        lastSeen = now
    }

    static func first(id: UUID, name: String?, rssi raw: Int, services: [String], manufacturer: Data?,
                      tx: Int?, connectable: Bool?, now: Date, demo: Bool = false) -> BLEPeripheralInfo {
        let start = (raw < 0 && raw != 127) ? Double(raw) : -100
        var p = BLEPeripheralInfo(id: id, name: name, rssi: start, lastRawRSSI: raw, history: [], lastHistoryAt: now,
                                  serviceUUIDs: services, manufacturerData: manufacturer, txPower: tx,
                                  connectable: connectable, firstSeen: now, lastSeen: now, isDemo: demo)
        if raw < 0 && raw != 127 { p.history = [Int(start)] }
        return p
    }
}

struct BLECharacteristicProperties: Equatable {
    var read = false, write = false, writeNoResponse = false, notify = false, indicate = false
    var other: [String] = []

    var labels: [String] {
        var out: [String] = []
        if read { out.append("Read") }
        if write { out.append("Write") }
        if writeNoResponse { out.append("Write, no response") }
        if notify { out.append("Notify") }
        if indicate { out.append("Indicate") }
        return out + other
    }
    var canWrite: Bool { write || writeNoResponse }
}

struct BLEDescriptorInfo: Identifiable, Equatable {
    let id: String
    let uuid: String
    var name: String? { BLEUUID.descriptorName(uuid) }
}

struct BLECharacteristicInfo: Identifiable, Equatable {
    let id: String            // stable within one connection: device|service|characteristic|index
    let uuid: String
    var properties: BLECharacteristicProperties
    var descriptors: [BLEDescriptorInfo] = []
    var isDemo = false
    var name: String? { BLEUUID.characteristicName(uuid) }
}

struct BLEServiceInfo: Identifiable, Equatable {
    let id: String
    let uuid: String
    var characteristics: [BLECharacteristicInfo] = []
    var isDemo = false
    var name: String? { BLEUUID.serviceName(uuid) }
}

struct BLEReading: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let deviceID: UUID
    let charID: String
    let serviceUUID: String
    let charUUID: String
    let data: Data
    let isDemo: Bool

    var hex: String { BLEHex.string(data) }
    var text: String? { BLEValueDecoder.text(data) }
    var number: String? { BLEValueDecoder.number(data) }
    var meaning: String? { BLEValueDecoder.meaning(charUUID: charUUID, data: data) }
}

struct BLEEvent: Identifiable {
    let id = UUID()
    let date: Date
    let deviceID: UUID?
    let message: String
    let isDemo: Bool
}

// MARK: - Hex helpers

enum BLEHex {
    static func string(_ d: Data) -> String {
        if d.isEmpty { return "(empty)" }
        return d.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - UUID names (Bluetooth SIG assigned numbers, only the ones Assay knows; everything else is "Unknown")

enum BLEUUID {
    /// CBUUID.uuidString gives "180F" for 16-bit UUIDs; this also folds full-length Bluetooth base UUIDs into the short form.
    static func normalise(_ raw: String) -> String {
        let u = raw.uppercased()
        if u.count == 4 || u.count == 8 { return u }
        let suffix = "-0000-1000-8000-00805F9B34FB"
        if u.count == 36, u.hasPrefix("0000"), u.hasSuffix(suffix) { return String(u.dropFirst(4).prefix(4)) }
        return u
    }

    static func display(_ uuid: String) -> String {
        uuid.count <= 8 ? "0x" + uuid : uuid
    }

    static let services: [String: String] = [
        "1800": "Generic Access",
        "180A": "Device Information",
        "180D": "Heart Rate",
        "180F": "Battery"
    ]

    static let characteristics: [String: String] = [
        // Generic Access
        "2A00": "Device Name",
        "2A01": "Appearance",
        // Battery
        "2A19": "Battery Level",
        // Device Information
        "2A23": "System ID",
        "2A24": "Model Number",
        "2A25": "Serial Number",
        "2A26": "Firmware Revision",
        "2A27": "Hardware Revision",
        "2A28": "Software Revision",
        "2A29": "Manufacturer Name",
        "2A50": "PnP ID",
        // Heart Rate
        "2A37": "Heart Rate Measurement",
        "2A38": "Body Sensor Location",
        "2A39": "Heart Rate Control Point"
    ]

    static let descriptors: [String: String] = [
        "2901": "Characteristic User Description",
        "2902": "Client Characteristic Configuration"
    ]

    static func serviceName(_ uuid: String) -> String? { services[uuid] }
    static func characteristicName(_ uuid: String) -> String? { characteristics[uuid] }
    static func descriptorName(_ uuid: String) -> String? { descriptors[uuid] }
}

// MARK: - Company identifiers (deliberately tiny: six common Bluetooth SIG company IDs, nothing else)

enum BLECompany {
    static let table: [(id: UInt16, name: String)] = [
        (0x004C, "Apple"),
        (0x0006, "Microsoft"),
        (0x00E0, "Google"),
        (0x0075, "Samsung"),
        (0x0059, "Nordic Semiconductor"),
        (0x0087, "Garmin")
    ]

    /// Company ID is the first two bytes of manufacturer data, little-endian.
    static func id(from data: Data?) -> UInt16? {
        guard let data, data.count >= 2 else { return nil }
        let b = [UInt8](data.prefix(2))
        return UInt16(b[0]) | (UInt16(b[1]) << 8)
    }

    static func name(_ id: UInt16) -> String? { table.first { $0.id == id }?.name }
    static func hex(_ id: UInt16) -> String { String(format: "0x%04X", id) }
}

// MARK: - Device type guess (Inferred, never Observed)

struct BLEGuess: Equatable {
    let label: String
    let confidence: Int

    static func make(services: [String], companyID: UInt16?) -> BLEGuess? {
        let rules: [(String, String, Int)] = [
            ("180D", "Heart rate monitor", 85),
            ("1809", "Thermometer", 80),
            ("1810", "Blood pressure monitor", 80),
            ("181D", "Weight scale", 80),
            ("1816", "Cycling speed or cadence sensor", 75),
            ("181A", "Environmental sensor", 70),
            ("1812", "Keyboard, mouse or other input device", 65)
        ]
        for (uuid, label, conf) in rules where services.contains(uuid) { return BLEGuess(label: label, confidence: conf) }
        let generic: Set<String> = ["1800", "1801", "180A", "180F"]
        if !services.isEmpty, services.allSatisfy({ generic.contains($0) }) {
            return BLEGuess(label: "Battery-powered accessory (kind not advertised)", confidence: 25)
        }
        if services.isEmpty, companyID == 0x004C {
            return BLEGuess(label: "Apple device (kind not advertised)", confidence: 30)
        }
        return nil
    }
}

// MARK: - Decoding values the user chose to read

enum BLEValueDecoder {
    static func text(_ d: Data) -> String? {
        guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return nil }
        let printable = s.unicodeScalars.allSatisfy { sc in
            sc.value >= 0x20 && sc.value != 0x7F || sc == "\n" || sc == "\t"
        }
        return printable ? s : nil
    }

    /// Little-endian unsigned integer for 1, 2, 4 or 8 bytes. Other lengths are not a sensible number.
    static func number(_ d: Data) -> String? {
        guard [1, 2, 4, 8].contains(d.count) else { return nil }
        var v: UInt64 = 0
        for (i, b) in d.enumerated() { v |= UInt64(b) << UInt64(8 * i) }
        return String(v)
    }

    /// Meaning for the few characteristics Assay knows. Returns nil rather than guessing.
    static func meaning(charUUID: String, data d: Data) -> String? {
        let b = [UInt8](d)
        switch charUUID {
        case "2A19":
            guard let v = b.first else { return nil }
            return v <= 100 ? "Battery \(v) %" : nil
        case "2A37":
            guard b.count >= 2 else { return nil }
            let sixteen = (b[0] & 0x01) != 0
            if sixteen { return b.count >= 3 ? "Heart rate \(Int(b[1]) | (Int(b[2]) << 8)) bpm" : nil }
            return "Heart rate \(b[1]) bpm"
        case "2A38":
            guard let v = b.first else { return nil }
            let names = ["Other", "Chest", "Wrist", "Finger", "Hand", "Ear lobe", "Foot"]
            return Int(v) < names.count ? "Sensor location: \(names[Int(v)])" : nil
        default:
            return nil
        }
    }
}

// MARK: - Write payloads (used only by the explicit Write sheet)

enum BLEWriteFormat: String, CaseIterable, Identifiable {
    case text = "Text", hex = "Hex", number = "Number"
    var id: String { rawValue }
}

enum BLEWriteWidth: Int, CaseIterable, Identifiable {
    case one = 1, two = 2, four = 4
    var id: Int { rawValue }
    var label: String { "\(rawValue) byte\(rawValue == 1 ? "" : "s")" }
}

struct BLEInputError: Error { let text: String }

enum BLEWritePayload {
    static let maxBytes = 512

    static func bytes(format: BLEWriteFormat, input: String, width: BLEWriteWidth) -> Result<Data, BLEInputError> {
        switch format {
        case .text:
            guard !input.isEmpty else { return .failure(BLEInputError(text: "Enter the text to send.")) }
            let d = Data(input.utf8)
            return d.count <= maxBytes ? .success(d) : .failure(BLEInputError(text: "That is \(d.count) bytes; the limit here is \(maxBytes)."))
        case .hex:
            var s = input.lowercased()
            s = s.replacingOccurrences(of: "0x", with: "")
            let cleaned = s.filter { !$0.isWhitespace && $0 != "," && $0 != ":" }
            guard !cleaned.isEmpty else { return .failure(BLEInputError(text: "Enter hex bytes, for example 01 FF 2A.")) }
            guard cleaned.allSatisfy({ $0.isHexDigit }) else { return .failure(BLEInputError(text: "Hex can only contain 0-9 and A-F.")) }
            guard cleaned.count % 2 == 0 else { return .failure(BLEInputError(text: "Hex needs two digits per byte; there is an odd digit.")) }
            var out = Data()
            var idx = cleaned.startIndex
            while idx < cleaned.endIndex {
                let next = cleaned.index(idx, offsetBy: 2)
                guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return .failure(BLEInputError(text: "Could not read the hex.")) }
                out.append(byte)
                idx = next
            }
            return out.count <= maxBytes ? .success(out) : .failure(BLEInputError(text: "That is \(out.count) bytes; the limit here is \(maxBytes)."))
        case .number:
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            guard let v = Int64(trimmed) else { return .failure(BLEInputError(text: "Enter a whole number, for example 42.")) }
            let bits = Int64(width.rawValue * 8)
            let maxUnsigned: Int64 = (Int64(1) << bits) - 1
            let minSigned: Int64 = -(Int64(1) << (bits - 1))
            guard v >= minSigned && v <= maxUnsigned else {
                return .failure(BLEInputError(text: "\(v) does not fit in \(width.label)."))
            }
            let u = UInt64(bitPattern: v)
            var out = Data()
            for i in 0..<width.rawValue { out.append(UInt8((u >> UInt64(8 * i)) & 0xFF)) }
            return .success(out)
        }
    }
}

// MARK: - Demo data (every value here is labelled Demo wherever it is shown)

enum BLEDemo {
    private static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "DE000000-0000-4000-8000-%012d", n))! }
    static let idPrefix = "DE000000"

    static func isDemoID(_ id: UUID) -> Bool { id.uuidString.hasPrefix(idPrefix) }

    static func devices(now: Date) -> [BLEPeripheralInfo] {
        struct Spec {
            let n: Int; let name: String?; let rssi: Int; let services: [String]; let mfr: [UInt8]?; let tx: Int?; let conn: Bool?
        }
        let specs: [Spec] = [
            Spec(n: 1, name: "Demo Heart Strap", rssi: -52, services: ["180D", "180F"], mfr: [0x87, 0x00, 0x01, 0x02, 0x03], tx: 4, conn: true),
            Spec(n: 2, name: "Demo Earbuds", rssi: -63, services: [], mfr: [0x4C, 0x00, 0x10, 0x05, 0x01, 0x18], tx: nil, conn: true),
            Spec(n: 3, name: "Demo Fitness Band", rssi: -71, services: ["180F", "180A"], mfr: [0x75, 0x00, 0x42, 0x04], tx: 0, conn: true),
            Spec(n: 4, name: nil, rssi: -83, services: [], mfr: [0x59, 0x00, 0xDE, 0xAD, 0xBE, 0xEF], tx: -8, conn: true),
            Spec(n: 5, name: "Demo Sensor Tag", rssi: -91, services: ["FFF0"], mfr: [0x34, 0x12, 0xAA, 0xBB], tx: nil, conn: false)
        ]
        return specs.map { s in
            var p = BLEPeripheralInfo.first(id: id(s.n), name: s.name, rssi: s.rssi, services: s.services,
                                            manufacturer: s.mfr.map { Data($0) }, tx: s.tx, connectable: s.conn, now: now, demo: true)
            // A fixed, repeatable wobble so the sparkline has something to draw. It is not a measurement.
            let wobble = [0, 2, -1, 3, -2, 1, -3, 2, 0, -1, 2, -2]
            p.history = (0..<40).map { i in s.rssi + wobble[(i + s.n) % wobble.count] }
            p.rssi = Double(s.rssi)
            p.lastHistoryAt = now
            return p
        }
    }

    /// Sample GATT tree and values for a demo device.
    static func gatt(for deviceID: UUID, name: String) -> (services: [BLEServiceInfo], values: [String: Data]) {
        func cid(_ s: String, _ c: String) -> String { "\(deviceID.uuidString)|\(s)|\(c)|0" }
        func ch(_ s: String, _ c: String, _ p: BLECharacteristicProperties, desc: Bool = false) -> BLECharacteristicInfo {
            BLECharacteristicInfo(id: cid(s, c), uuid: c, properties: p,
                                  descriptors: desc ? [BLEDescriptorInfo(id: cid(s, c) + "|2902", uuid: "2902")] : [], isDemo: true)
        }
        var r = BLECharacteristicProperties(); r.read = true
        var n = BLECharacteristicProperties(); n.notify = true
        var rw = BLECharacteristicProperties(); rw.read = true; rw.write = true
        let svcs: [BLEServiceInfo] = [
            BLEServiceInfo(id: "\(deviceID.uuidString)|1800", uuid: "1800", characteristics: [ch("1800", "2A00", r), ch("1800", "2A01", r)], isDemo: true),
            BLEServiceInfo(id: "\(deviceID.uuidString)|180A", uuid: "180A",
                           characteristics: [ch("180A", "2A29", r), ch("180A", "2A24", r), ch("180A", "2A26", r)], isDemo: true),
            BLEServiceInfo(id: "\(deviceID.uuidString)|180F", uuid: "180F", characteristics: [ch("180F", "2A19", r)], isDemo: true),
            BLEServiceInfo(id: "\(deviceID.uuidString)|180D", uuid: "180D",
                           characteristics: [ch("180D", "2A37", n, desc: true), ch("180D", "2A38", r)], isDemo: true),
            BLEServiceInfo(id: "\(deviceID.uuidString)|FFF0", uuid: "FFF0", characteristics: [ch("FFF0", "FFF1", rw)], isDemo: true)
        ]
        let values: [String: Data] = [
            cid("1800", "2A00"): Data(name.utf8),
            cid("1800", "2A01"): Data([0x41, 0x03]),
            cid("180A", "2A29"): Data("Demo Maker Ltd".utf8),
            cid("180A", "2A24"): Data("DM-100".utf8),
            cid("180A", "2A26"): Data("1.0.0-demo".utf8),
            cid("180F", "2A19"): Data([87]),
            cid("180D", "2A38"): Data([1]),
            cid("FFF0", "FFF1"): Data([0x00, 0x01])
        ]
        return (svcs, values)
    }
}
