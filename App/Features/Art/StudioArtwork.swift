import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct StudioDataDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    let data: Data
    init(_ data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { throw CocoaError(.fileReadUnsupportedScheme) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum StudioArtwork {
    enum Problem: LocalizedError { case unsupported, size
        var errorDescription: String? { self == .size ? "Image exceeds the local editor’s size limit." : "This image could not be opened." }
    }
    static func readImage(_ url: URL, pixels: Int = 2304) throws -> CGImage {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let info=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey]);guard info.isRegularFile==true, info.isSymbolicLink != true, let count=info.fileSize, count>0,count<=20*1024*1024 else {throw Problem.size}
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache:false] as CFDictionary) else {throw Problem.unsupported}
        return try decode(src, pixels:pixels)
    }
    static func readBytes(_ data:Data, pixels:Int = 2304) throws -> CGImage {
        guard let src=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary) else{throw Problem.unsupported};return try decode(src,pixels:pixels)
    }
    static func dimensions(_ data: Data) throws -> (Int,Int) {
        guard let src=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary), let p=CGImageSourceCopyPropertiesAtIndex(src,0,nil) as? [CFString:Any], let w=p[kCGImagePropertyPixelWidth] as? Int, let h=p[kCGImagePropertyPixelHeight] as? Int,w>0,h>0,w<=8192,h<=8192,w*h<=24_000_000 else {throw Problem.size};return(w,h)
    }
    private static func decode(_ s:CGImageSource,pixels:Int) throws -> CGImage {
        guard let p=CGImageSourceCopyPropertiesAtIndex(s,0,nil) as? [CFString:Any],let w=p[kCGImagePropertyPixelWidth] as? Int,let h=p[kCGImagePropertyPixelHeight] as? Int,(1...20_000).contains(w),(1...20_000).contains(h),w*h<=80_000_000 else {throw Problem.size}
        let opts:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:pixels,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceShouldCacheImmediately:true]
        guard let im=CGImageSourceCreateThumbnailAtIndex(s,0,opts as CFDictionary) else{throw Problem.unsupported};return im
    }
    static func fittedPNG(_ image:CGImage, width:Int,height:Int) throws -> Data {
        guard width>0,height>0,width<=8192,height<=8192,width*height<=24_000_000,let space=CGColorSpace(name:CGColorSpace.sRGB),let cg=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw Problem.size}
        let scale=max(CGFloat(width)/CGFloat(image.width),CGFloat(height)/CGFloat(image.height));let w=CGFloat(image.width)*scale,h=CGFloat(image.height)*scale;cg.interpolationQuality = .high;cg.draw(image,in:CGRect(x:(CGFloat(width)-w)/2,y:(CGFloat(height)-h)/2,width:w,height:h));guard let im=cg.makeImage() else{throw Problem.unsupported};return try png(im)
    }
    static func png(_ image:CGImage) throws -> Data {
        let bytes=NSMutableData();guard let d=CGImageDestinationCreateWithData(bytes as CFMutableData,UTType.png.identifier as CFString,1,nil) else {throw Problem.unsupported};CGImageDestinationAddImage(d,image,nil);guard CGImageDestinationFinalize(d) else {throw Problem.unsupported};return bytes as Data
    }
}
