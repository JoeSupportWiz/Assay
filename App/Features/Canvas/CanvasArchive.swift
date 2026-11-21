import Foundation

/// No files are extracted to disk, CAML is never loaded, and referenced URLs are never opened.
struct CanvasIndex {
    let fileCount:Int, camlCount:Int, totalBytes:Int, images:[String]
    static let archiveCap=96*1024*1024, fileCap=8*1024*1024
    static let imageTypes:Set<String>=["png","jpg","jpeg","heic","webp"]
    static func ext(_ name:String)->String { (name as NSString).pathExtension.lowercased() }
    init(reader r:SignetZipReader)throws {
        guard r.fileSize<=Self.archiveCap,r.entries.count<=3000,!r.entries.isEmpty else{throw CanvasFailure.limit}
        var seen=Set<String>(), imgs=[String](),size=0,files=0,caml=0
        for e in r.entries {
            guard seen.insert(e.name).inserted,e.name.utf8.count<=2048,e.flags & 1 == 0,[0,8].contains(e.method),!e.name.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else {throw CanvasFailure.entry}
            guard e.compressedSize<=Self.fileCap,e.uncompressedSize<=Self.fileCap,size<=Self.archiveCap-e.uncompressedSize else {throw CanvasFailure.limit};size+=e.uncompressedSize
            if !e.isDirectory { files+=1;let kind=Self.ext(e.name);if Self.imageTypes.contains(kind){imgs.append(e.name)};if kind=="caml"{caml+=1} }
        }
        fileCount=files;totalBytes=size;camlCount=caml;images=imgs.sorted()
    }
}
enum CanvasFailure:LocalizedError {case limit,entry,missing,png
    var errorDescription:String? {switch self {case .limit:return "Choose a project under 96 MiB, with at most 3,000 entries of up to 8 MiB each.";case .entry:return "This archive has duplicate or unsupported entries.";case .missing:return "The selected image is no longer present.";case .png:return "Replacement is available for PNG layers only."}}
}
struct CanvasArchive {
    private static func read<T>(_ url:URL,_ body:(SignetZipReader)throws->T)throws->T {
        let ok=url.startAccessingSecurityScopedResource();defer {if ok{url.stopAccessingSecurityScopedResource()}}
        let info=try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey]);guard info.isRegularFile==true,let bytes=info.fileSize,bytes<=CanvasIndex.archiveCap else{throw CanvasFailure.limit}
        return try body(SignetZipReader(url:url))
    }
    static func inspect(_ url:URL)throws->CanvasIndex { try read(url){try CanvasIndex(reader:$0)} }
    static func asset(_ url:URL,_ name:String)throws->Data {try read(url){r in guard let e=r.entry(named:name) else{throw CanvasFailure.missing};return try r.extract(e)}}
    /// Export as a separate stored ZIP, copying each other entry's uncompressed bytes exactly. ZIP metadata is normalised.
    static func replacing(_ url:URL,_ name:String,with replacement:Data)throws->Data {
        guard CanvasIndex.ext(name)=="png" else {throw CanvasFailure.png};guard replacement.count<=CanvasIndex.fileCap else {throw CanvasFailure.limit}
        return try read(url){r in let i=try CanvasIndex(reader:r);guard i.images.contains(name),let prior=r.entry(named:name),i.totalBytes-prior.uncompressedSize+replacement.count<=CanvasIndex.archiveCap else{throw CanvasFailure.limit}
            var local=Data(),central=Data()
            for e in r.entries {try Task.checkCancellation();let d=e.name==name ? replacement : try r.extract(e),fn=Data(e.name.utf8),pos=local.count,crc=SignetZipReader.crc32(Array(d));
                func body(_ x:inout Data){x.c16(20);x.c16(0x800);x.c16(0);x.c16(0);x.c16(33);x.c32(crc);x.c32(UInt32(d.count));x.c32(UInt32(d.count));x.c16(UInt16(fn.count));x.c16(0)}
                local.c32(0x04034b50);body(&local);local.append(fn);local.append(d)
                central.c32(0x02014b50);central.c16(20);body(&central);central.c16(0);central.c16(0);central.c16(0);central.c32(e.isDirectory ? 16:0);central.c32(UInt32(pos));central.append(fn)
            }
            let off=local.count;local.append(central);local.c32(0x06054b50);local.c16(0);local.c16(0);local.c16(UInt16(r.entries.count));local.c16(UInt16(r.entries.count));local.c32(UInt32(central.count));local.c32(UInt32(off));local.c16(0);guard local.count<=CanvasIndex.archiveCap else{throw CanvasFailure.limit};return local
        }
    }
}
private extension Data {
    mutating func c16(_ v:UInt16){append(UInt8(truncatingIfNeeded:v));append(UInt8(truncatingIfNeeded:v>>8))}
    mutating func c32(_ v:UInt32){c16(UInt16(truncatingIfNeeded:v));c16(UInt16(truncatingIfNeeded:v>>16))}
}
