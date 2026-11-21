import Foundation

struct LabSwatch: Equatable, Sendable {
    enum Origin: String, Sendable { case extracted = "Extracted", derived = "Derived tone", adjusted = "Adjusted" }
    var hex: UInt32
    var origin: Origin
    var locked = false
}

enum PaletteLabCore {
    static let edge = 128
    static let count = 5

    private static func channel(_ rgb: UInt32, _ shift: Int) -> Int { Int((rgb >> shift) & 255) }
    private static func pack(_ r: Int, _ g: Int, _ b: Int) -> UInt32 { UInt32(r << 16 | g << 8 | b) }

    static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ shift: Int) -> Double {
            let s = Double(channel(rgb, shift)) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    static func suggestsBlack(on rgb: UInt32) -> Bool { contrast(rgb, 0) >= contrast(rgb, 0xFFFFFF) }

    private static func distance(_ a: UInt32, _ b: UInt32) -> Int {
        let r = channel(a, 16) - channel(b, 16), g = channel(a, 8) - channel(b, 8), b = channel(a, 0) - channel(b, 0)
        return r*r + g*g + b*b
    }

    private struct Bin {
        var weight = 0, r = 0, g = 0, b = 0
        var rgb: UInt32 { pack(r / weight, g / weight, b / weight) }
    }

    /// Tightly packed, premultiplied sRGB RGBA8. No opaque canvas behind transparent pixels.
    static func extract(_ bytes: [UInt8], keeping previous: [LabSwatch] = []) -> [LabSwatch]? {
        guard !bytes.isEmpty, bytes.count <= edge * edge * 4, bytes.count.isMultiple(of: 4) else { return nil }
        var bins: [Int: Bin] = [:]
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[i + 3])
            guard alpha > 0 else { continue }
            func straight(_ offset: Int) -> Int { min(255, (255 * Int(bytes[i + offset]) + alpha / 2) / alpha) }
            let r = straight(0), g = straight(1), b = straight(2)
            let key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            var bin = bins[key, default: Bin()]
            bin.weight += alpha; bin.r += alpha*r; bin.g += alpha*g; bin.b += alpha*b
            bins[key] = bin
        }
        let ranked = bins.sorted { a, b in
            a.value.weight == b.value.weight ? a.key < b.key : a.value.weight > b.value.weight
        }
        guard let base = ranked.first?.value.rgb else { return nil }
        var slots = [LabSwatch?](repeating: nil, count: count)
        for (i, swatch) in previous.prefix(count).enumerated() where swatch.locked { slots[i] = swatch }
        func separation(_ hex: UInt32) -> Int { slots.compactMap { $0.map { distance(hex, $0.hex) } }.min() ?? Int.max }
        for bin in ranked {
            guard let i = slots.firstIndex(of: nil) else { break }
            let hex = bin.value.rgb
            if separation(hex) >= 48*48 { slots[i] = LabSwatch(hex: hex, origin: .extracted) }
        }
        // Fill only missing slots with tints/shades of the dominant bin, furthest first.
        if slots.contains(nil) {
            var tones: [UInt32] = []
            for end in [0, 255] {
                for step in 1...16 {
                    func mix(_ shift: Int) -> Int { (channel(base, shift) * (16 - step) + end * step) / 16 }
                    tones.append(pack(mix(16), mix(8), mix(0)))
                }
            }
            while let i = slots.firstIndex(of: nil), let tone = tones.max(by: { separation($0) < separation($1) }) {
                slots[i] = LabSwatch(hex: tone, origin: .derived)
            }
        }
        return slots.compactMap { $0 }
    }
}
