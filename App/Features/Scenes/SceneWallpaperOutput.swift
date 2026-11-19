import SwiftUI
import UniformTypeIdentifiers
import ImageIO

/// Render a new PNG locally. Never reads the user's wallpaper or installs a profile.
struct SceneWallpaperOutput: View {
    let palette: WallpaperPalette
    @State private var doc: WallpaperPNG?
    @State private var presenting = false
    @State private var rendering = false
    @State private var error = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                let bounds = UIScreen.main.nativeBounds
                let width = Int(min(bounds.width,bounds.height)), height = Int(max(bounds.width,bounds.height))
                let swatches = palette.hex
                rendering = true; error = false
                Task {
                    let bytes = await Task.detached(priority: .userInitiated) { Self.render(swatches, width, height) }.value
                    rendering = false
                    guard let bytes else { error = true; return }
                    doc = WallpaperPNG(bytes: bytes); presenting = true
                }
            } label: { Label(rendering ? "Rendering…" : "Export wallpaper PNG", systemImage: "photo.badge.arrow.down") }
            .disabled(rendering)
            Text("A portrait gradient from this scene’s colours, at this display’s native pixel dimensions. Save it in Files, then use Photos or Wallpaper Settings to set it yourself.").font(.footnote).foregroundStyle(.secondary)
            if error { Text("Couldn’t render or export the image. Try another destination.").font(.footnote) }
        }
        .fileExporter(isPresented: $presenting, document: doc, contentType: .png, defaultFilename: "Assay-wallpaper.png") { result in
            doc = nil
            if case .failure(let e) = result, (e as NSError).code != NSUserCancelledError { error = true }
        }
    }
    nonisolated private static func render(_ colours: [UInt32], _ w: Int, _ h: Int) -> Data? {
        guard colours.count >= 2, w > 0, h > 0, w <= 4096, h <= 5000, w*h <= 10_000_000,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let stops = colours.prefix(8).map { CGColor(srgbRed: CGFloat(($0 >> 16) & 255)/255, green: CGFloat(($0 >> 8) & 255)/255, blue: CGFloat($0 & 255)/255, alpha: 1) }
        guard let gradient=CGGradient(colorsSpace:space,colors:stops as CFArray,locations:nil) else { return nil }
        cg.drawLinearGradient(gradient,start:CGPoint(x:0,y:h),end:CGPoint(x:w,y:0),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation]);guard let image=cg.makeImage() else {return nil}
        let data=NSMutableData();guard let target=CGImageDestinationCreateWithData(data as CFMutableData,UTType.png.identifier as CFString,1,nil) else {return nil}
        CGImageDestinationAddImage(target,image,nil);return CGImageDestinationFinalize(target) ? data as Data : nil
    }
}
private struct WallpaperPNG: FileDocument {
    static let readableContentTypes: [UTType] = [.png]
    var bytes: Data
    init(bytes: Data) {self.bytes=bytes}
    init(configuration: ReadConfiguration) throws {guard let d=configuration.file.regularFileContents else {throw CocoaError(.fileReadCorruptFile)};bytes=d}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:bytes) }
}
