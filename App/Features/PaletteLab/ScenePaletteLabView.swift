import SwiftUI
import UniformTypeIdentifiers

@MainActor struct ScenePaletteLabView: View {
    let onUse: (WallpaperPalette) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var pending: URL?
    @State private var problem: String?
    @State private var slots: [LabSwatch] = []
    @State private var selected = 0

    init(onUse: @escaping (WallpaperPalette) -> Void) { self.onUse = onUse }

    var body: some View {
        Form {
            Section {
                Button { picking = true } label: { Label("Choose image from Files", systemImage: "folder") }
                if pending != nil { ProgressView("Sampling colours…") }
                if let problem { Text(problem).foregroundStyle(.secondary) }
            } footer: { Text("JPEG, PNG or HEIC, up to 20 MiB. The image is sampled locally and isn’t saved by Palette Lab.") }
            if slots.indices.contains(selected) {
                Section {
                    ForEach(slots.indices, id: \.self) { i in
                        let swatch = slots[i]
                        Button { selected = i } label: {
                            HStack {
                                Circle().fill(Color(hex: swatch.hex)).frame(width: 28, height: 28)
                                    .overlay { Circle().strokeBorder(.secondary, lineWidth: 0.5) }
                                VStack(alignment: .leading) {
                                    Text(String(format: "#%06X", swatch.hex)).font(.body.monospaced())
                                    Text(swatch.origin.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if swatch.locked { Image(systemName: "lock.fill").accessibilityLabel("Locked") }
                                if i == selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(i == selected ? .isSelected : [])
                    }
                } header: { Text("Swatches") } footer: {
                    Text("Select a swatch to check or edit it. Derived tones fill gaps when the image has fewer than five distinct colours.")
                }
                LabSwatchEditor(swatch: $slots[selected]).id(selected)
                Section {
                    Button("Use palette in draft") {
                        let sorted = slots.map(\.hex).sorted { PaletteLabCore.luminance($0) > PaletteLabCore.luminance($1) }
                        onUse(WallpaperPalette(hex: sorted))
                        dismiss()
                    }.disabled(!distinct)
                } footer: {
                    Text(distinct ? "Only the draft’s five colours change. Save the scene separately." : "Choose five different colours to use this palette.")
                }
            }
        }
        .disabled(pending != nil)
        .navigationTitle("Palette Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.jpeg, .png, .heic]) { result in
            do { pending = try result.get(); problem = nil }
            catch { if (error as NSError).code != NSUserCancelledError { problem = error.localizedDescription } }
        }
        .task(id: pending) {
            guard let url = pending else { return }
            do {
                let next = try await PaletteLabReader.shared.read(url, keeping: slots)
                try Task.checkCancellation()
                slots = next
            } catch { if !Task.isCancelled { problem = error.localizedDescription } }
            if !Task.isCancelled { pending = nil }
        }
    }

    private var distinct: Bool { Set(slots.map(\.hex)).count == PaletteLabCore.count }
}

private struct LabSwatchEditor: View {
    @Binding var swatch: LabSwatch
    @Environment(\.self) private var environment

    var body: some View {
        Section {
            ColorPicker("Adjust colour", selection: colour, supportsOpacity: false)
            Toggle("Lock on reimport", isOn: $swatch.locked)
        } header: { Text("Selected swatch") } footer: { Text("Editing a colour locks it. Locked swatches stay in place when you choose another image.") }
        Section {
            let black = PaletteLabCore.suggestsBlack(on: swatch.hex)
            Text(black ? "Suggested: black text" : "Suggested: white text")
                .font(.headline).padding().frame(maxWidth: .infinity)
                .foregroundStyle(black ? Color.black : Color.white)
                .background(Color(hex: swatch.hex), in: RoundedRectangle(cornerRadius: 8))
            ratioRow("Black text", foreground: 0)
            ratioRow("White text", foreground: 0xFFFFFF)
        } header: { Text("Overlay contrast") } footer: {
            Text("WCAG normal text needs at least 4.5:1. This compares opaque text with this solid swatch, not the whole photo. The suggestion doesn’t change your scene’s text.")
        }
    }

    private func ratioRow(_ label: String, foreground: UInt32) -> some View {
        let ratio = PaletteLabCore.contrast(swatch.hex, foreground)
        return VStack(alignment: .leading) {
            Text(label)
            Text("\(ratio, format: .number.precision(.fractionLength(2))):1 · \(ratio >= 4.5 ? "Meets target" : "Below target")")
                .font(.subheadline).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }

    private var colour: Binding<Color> {
        Binding(get: { Color(hex: swatch.hex) }, set: { newValue in
            let c = newValue.resolve(in: environment)
            func byte(_ value: Float) -> UInt32 { UInt32((min(1, max(0, value)) * 255).rounded()) }
            let hex = byte(c.red) << 16 | byte(c.green) << 8 | byte(c.blue)
            if hex != swatch.hex { swatch = LabSwatch(hex: hex, origin: .adjusted, locked: true) }
        })
    }
}
