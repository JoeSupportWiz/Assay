import Foundation

@main enum PaletteLabTests {
    static func main() {
        typealias Core = PaletteLabCore
        precondition(abs(Core.contrast(0xFFFFFF, 0) - 21) < 1e-10)
        precondition(Core.contrast(0x781234, 0x781234) == 1)
        precondition(abs(Core.luminance(0x808080) - 0.21586) < 0.00001)
        precondition(Core.suggestsBlack(on: 0x777777) && !Core.suggestsBlack(on: 0x757575))
        for gray: UInt32 in 0...255 {
            let a = gray * 0x010101, b = 0xFFFFFF - a
            let l = Core.luminance(a), ratio = Core.contrast(a, b)
            precondition(l.isFinite && (0...1).contains(l))
            precondition(ratio.isFinite && (1...21).contains(ratio) && ratio == Core.contrast(b, a))
        }
        let gray: [UInt8] = [128, 128, 128, 255]
        let mono = Core.extract(gray)!
        precondition(mono.count == 5 && Set(mono.map(\.hex)).count == 5)
        precondition(mono[0] == LabSwatch(hex: 0x808080, origin: .extracted))
        precondition(mono.dropFirst().allSatisfy { $0.origin == .derived })
        precondition(mono.allSatisfy { ($0.hex >> 16) * 0x010101 == $0.hex })
        precondition(Core.extract(Array(repeating: gray, count: Core.edge * Core.edge).flatMap { $0 }) == mono)
        let ramp = [0, 64, 128, 192, 255].flatMap { (level: UInt8) -> [UInt8] in [level, level, level, 255] }
        precondition(Core.extract(ramp)!.allSatisfy { $0.origin == .extracted })
        let red: [UInt8] = [255, 0, 0, 255], green: [UInt8] = [0, 255, 0, 255]
        let mixed = red + green + green + [0, 230, 0, 255]
        let observed = Core.extract(mixed)!.filter { $0.origin == .extracted }
        precondition(observed.map(\.hex) == [0x00FF00, 0xFF0000])
        let padded = [UInt8](repeating: 0, count: 256) + [128, 0, 0, 128] + green
        precondition(Core.extract(padded)!.prefix(2).map(\.hex) == [0x00FF00, 0xFF0000])
        var locked = mono
        locked[2] = LabSwatch(hex: 0x123456, origin: .adjusted, locked: true)
        let merged = Core.extract(mixed, keeping: locked)!
        precondition(merged[2] == locked[2] && merged[0].hex == 0x00FF00 && Set(merged.map(\.hex)).count == 5)
        precondition(Core.extract([]) == nil && Core.extract([1, 2, 3]) == nil && Core.extract([0, 0, 0, 0]) == nil)
        precondition(Core.extract([UInt8](repeating: 255, count: (Core.edge * Core.edge + 1) * 4)) == nil)
        print("Palette Lab: contrast, extraction, provenance, locks, alpha and bounds passed")
    }
}
