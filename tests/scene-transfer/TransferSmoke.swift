import Foundation

// Only the two SwiftUI-bound appearance types are replaced. Use real SavedScene and transitions.
enum ThemeID: String, Codable { case auto, light, dark, millennium, pinstripe, wallpaper }
struct WallpaperPalette: Equatable, Codable { var hex: [UInt32] }

@main struct TransferSmoke {
    static func main() throws {
        let appearance = SceneAppearance(theme: .wallpaper, palette: WallpaperPalette(hex: [0xFEED00, 7, 7, 0, 0xFFFFFF]))
        let original = SavedScene(name: "Evening", appearance: appearance, wallpaperNote: "Secret synthetic note",
                                  iconNote: "Text only: https://example.invalid/a", widgetNote: "Top\n\"left\" 🐈")
        var library = SceneLibraryState()
        try library.save(original, creating: true)
        _ = try library.activate(original, before: appearance, live: appearance)
        let before = library
        let plain = try ScenePacket(scene: original, includeNotes: false).encoded()
        let obj = try JSONSerialization.jsonObject(with: plain) as! [String: Any]
        precondition(Set(obj.keys) == ["schema", "name", "theme", "palette"])
        let noNotes = try ScenePacket.decode(plain).newLocalScene()
        precondition(noNotes.wallpaperNote.isEmpty && noNotes.iconNote.isEmpty && noNotes.widgetNote.isEmpty)
        let all = ScenePacket(scene: original, includeNotes: true)
        let reviewed = try ScenePacket.decode(all.encoded())
        precondition(reviewed == all && library == before)
        let a = try reviewed.newLocalScene(), b = try reviewed.newLocalScene()
        var expected = original; expected.id = a.id
        precondition(a == expected && a.id != b.id && a.id != original.id)
        try library.save(a, creating: true); try library.save(b, creating: true)
        precondition(library.scenes == [original, a, b] && library.selectedID == before.selectedID && library.undo == before.undo)

        let base = ##"{"schema":"assay.scene.v1","name":"N","theme":"dark","palette":["#123abc","#123ABC","#000000","#ffffff","#123123"]}"##
        func replaced(_ old: String, _ new: String) -> String {
            precondition(base.contains(old)); return base.replacingOccurrences(of: old, with: new)
        }
        func reject(_ data: Data) {
            do { _ = try ScenePacket.decode(data); fatalError("accepted invalid synthetic input") } catch { }
        }
        for bad in ["[]", "{}", base + "{}", String(base.dropLast()), replaced("v1", "v2"), replaced("dark", "future"),
                    replaced("\"name\":\"N\",", ""), replaced("\"N\"", "null"), replaced("N", " N"), replaced("N", ""),
                    replaced("N", String(repeating: "n", count: 81)), replaced("N", #"\u202e"#), replaced("N", #"\x"#),
                    replaced("#123abc", "#abc"), replaced("#123abc", "#12345Ｇ"), replaced("#123abc", "#12345G"),
                    replaced("#123abc", "#00123456"), replaced("\"#123abc\",", ""), replaced("]", ",\"#000000\"]"),
                    replaced("\"#123abc\"", "123"), replaced("}", ",}"), replaced("]", ",]"),
                    replaced("}", #", "na\u006de":"other"}"#), replaced("}", #", "palette":[]}"#),
                    replaced("}", #", "id":"external"}"#), replaced("}", #", "action":"open"}"#),
                    replaced("}", #", "url":"https://example.invalid/"}"#), replaced("}", #", "iconNote":{"url":"x"}}"#),
                    replaced("}", #", "iconNote":null}"#), replaced("N", #"\u0000"#),
                    replaced("}", ",\"iconNote\":\"" + String(repeating: "x", count: 2_001) + "\"}")] {
            reject(Data(bad.utf8))
        }
        var invalidUTF8 = Data(base.utf8); invalidUTF8[invalidUTF8.firstIndex(of: 78)!] = 255; reject(invalidUTF8)
        var limit = Data(base.utf8); limit.append(Data(repeating: 32, count: ScenePacket.byteLimit - limit.count))
        _ = try ScenePacket.decode(limit); limit.append(32); reject(limit)
        var badLocal = original; badLocal.appearance.palette.hex[0] = 0x1000000
        do { _ = try ScenePacket(scene: badLocal, includeNotes: false).encoded(); fatalError("invalid local RGB exported") }
        catch ScenePacket.Fault.palette { }
        print("PASS: v1 privacy, strict schema, UTF-8/RGB/size boundaries, fresh IDs and inert create-only round trip")
    }
}
