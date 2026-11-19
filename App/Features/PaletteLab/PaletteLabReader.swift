import CoreGraphics
import Foundation

actor PaletteLabReader {
    static let shared = PaletteLabReader()

    func read(_ url: URL, keeping slots: [LabSwatch]) throws -> [LabSwatch] {
        try Task.checkCancellation()
        let image = try StudioArtwork.readImage(url, pixels: PaletteLabCore.edge)
        let w = image.width, h = image.height
        let bounds = 1...PaletteLabCore.edge
        guard bounds.contains(w), bounds.contains(h), let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw StudioArtwork.Problem.size
        }
        // Match the oriented thumbnail exactly; don't introduce letterbox pixels into the histogram.
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        try bytes.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            let flags = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space, bitmapInfo: flags) else {
                throw StudioArtwork.Problem.unsupported
            }
            ctx.draw(image, in: rect)
        }
        try Task.checkCancellation()
        guard let palette = PaletteLabCore.extract(bytes, keeping: slots) else { throw EmptyImage() }
        return palette
    }

    private struct EmptyImage: LocalizedError {
        var errorDescription: String? { "This image is fully transparent. Choose one with visible colours." }
    }
}
