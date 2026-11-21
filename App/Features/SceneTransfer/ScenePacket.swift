import Foundation

/// Closed v1 wire format, deliberately independent of SavedScene, defaults and SwiftUI.
struct ScenePacket: Encodable, Equatable, Sendable {
    static let schemaID = "assay.scene.v1"
    static let byteLimit = 65_536
    let schema: String
    let name: String
    let theme: String
    let palette: [String]
    let wallpaperNote: String?
    let iconNote: String?
    let widgetNote: String?

    enum Fault: LocalizedError {
        case size, format, schema, name, theme, palette, note
        var errorDescription: String? {
            switch self {
            case .size: "Use a scene JSON file no larger than 64 KiB."
            case .format: "Expected one Assay scene with only the documented fields, each present at most once."
            case .schema: "This scene format or version is not supported."
            case .name: "Use a trimmed, single-line scene name of 1–80 characters (up to 320 UTF-8 bytes)."
            case .theme: "This scene’s theme is not supported."
            case .palette: "A scene needs five ordered RGB colours in #RRGGBB format."
            case .note: "Each note must be plain text, up to 2,000 characters and 8,000 UTF-8 bytes, without unsafe controls."
            }
        }
    }

    private func checked() throws -> Self {
        guard schema == Self.schemaID else { throw Fault.schema }
        guard ["auto", "light", "dark", "millennium", "pinstripe", "wallpaper"].contains(theme) else { throw Fault.theme }
        func safe(_ s: String, multiline: Bool) -> Bool {
            s.unicodeScalars.allSatisfy { c in
                if multiline && (c == "\n" || c == "\t") { return true }
                // Exclude controls, paragraph/line separators and explicit bidi controls.
                return c.properties.generalCategory != .control && c != "\u{2028}" && c != "\u{2029}"
                    && !c.properties.isBidiControl
            }
        }
        guard name.utf8.count <= 320, (1...80).contains(name.count), safe(name, multiline: false),
              name == name.trimmingCharacters(in: .whitespacesAndNewlines) else { throw Fault.name }
        guard palette.count == 5, palette.allSatisfy({ code in
            let b = code.utf8
            return b.count == 7 && b.first == 35 && b.dropFirst().allSatisfy {
                (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
            }
        }) else { throw Fault.palette }
        for case let note? in [wallpaperNote, iconNote, widgetNote] {
            guard note.utf8.count <= 8_000, note.count <= 2_000, safe(note, multiline: true) else { throw Fault.note }
        }
        return self
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(checked())
        guard data.count <= Self.byteLimit else { throw Fault.size }
        return data
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= byteLimit else { throw Fault.size }
        // Decode only a flat object of strings and one string array. General-purpose
        // keyed decoders can silently collapse duplicate keys and ignore unknown fields.
        var r = Reader(bytes: Array(data))
        var fields: [String: String] = [:], colours: [String]?
        try r.expect(123) // {
        repeat {
            let key = try r.string()
            try r.expect(58) // :
            switch key {
            case "palette":
                guard colours == nil else { throw Fault.format }
                try r.expect(91) // [
                var list: [String] = []
                repeat {
                    guard list.count < 5 else { throw Fault.palette }
                    list.append(try r.string())
                } while r.take(44)
                try r.expect(93)
                colours = list
            case "schema", "name", "theme", "wallpaperNote", "iconNote", "widgetNote":
                guard fields[key] == nil else { throw Fault.format }
                fields[key] = try r.string()
            default: throw Fault.format
            }
        } while r.take(44)
        try r.expect(125)
        r.skipSpace()
        guard r.i == r.bytes.count, let schema = fields["schema"], let name = fields["name"],
              let theme = fields["theme"], let colours else { throw Fault.format }
        return try Self(schema: schema, name: name, theme: theme, palette: colours,
                        wallpaperNote: fields["wallpaperNote"], iconNote: fields["iconNote"], widgetNote: fields["widgetNote"]).checked()
    }

    private struct Reader {
        let bytes: [UInt8]
        var i = 0
        mutating func skipSpace() {
            while i < bytes.count && [9, 10, 13, 32].contains(bytes[i]) { i += 1 }
        }
        mutating func take(_ byte: UInt8) -> Bool {
            skipSpace()
            guard i < bytes.count, bytes[i] == byte else { return false }
            i += 1
            return true
        }
        mutating func expect(_ byte: UInt8) throws { guard take(byte) else { throw Fault.format } }
        mutating func string() throws -> String {
            try expect(34)
            let start = i - 1
            while i < bytes.count {
                let b = bytes[i]
                i += 1
                guard b >= 32 else { throw Fault.format }
                if b == 92 { i += 1; continue } // JSONDecoder validates the escape itself.
                if b == 34 {
                    let token = Data(bytes[start..<i])
                    guard String(data: token, encoding: .utf8) != nil,
                          let s = try? JSONDecoder().decode(String.self, from: token) else { throw Fault.format }
                    return s
                }
            }
            throw Fault.format
        }
    }
}
