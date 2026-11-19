import Foundation

extension ScenePacket {
    init(scene: SavedScene, includeNotes: Bool) {
        func note(_ value: String) -> String? { includeNotes && !value.isEmpty ? value : nil }
        self.init(schema: Self.schemaID, name: scene.name, theme: scene.appearance.theme.rawValue,
                  palette: scene.appearance.palette.hex.map { String(format: "#%06X", $0) },
                  wallpaperNote: note(scene.wallpaperNote), iconNote: note(scene.iconNote), widgetNote: note(scene.widgetNote))
    }

    /// Only called with a validated review snapshot. SavedScene supplies a new UUID each time.
    func newLocalScene() throws -> SavedScene {
        guard let localTheme = ThemeID(rawValue: theme) else { throw Fault.theme }
        let rgb = try palette.map { code -> UInt32 in
            guard let value = UInt32(code.dropFirst(), radix: 16) else { throw Fault.palette }
            return value
        }
        return SavedScene(name: name, appearance: SceneAppearance(theme: localTheme, palette: WallpaperPalette(hex: rgb)),
                          wallpaperNote: wallpaperNote ?? "", iconNote: iconNote ?? "", widgetNote: widgetNote ?? "")
    }
}
