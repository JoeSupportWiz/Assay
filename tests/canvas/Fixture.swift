import Foundation
@main enum CanvasFixture {
    static func main() throws {
        let src=URL(fileURLWithPath:CommandLine.arguments[1]),out=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".zip");defer{try? FileManager.default.removeItem(at:out)}
        let index=try CanvasArchive.inspect(src);precondition(index.fileCount==3 && index.images.count==2);let first=index.images[0],second=index.images[1];let a=try CanvasArchive.asset(src,first),b=try CanvasArchive.asset(src,second);precondition(a != b)
        let original=try Data(contentsOf:src);try CanvasArchive.replacing(src,first,with:b).write(to:out);let roundTrip=try CanvasArchive.asset(out,first),unchanged=try CanvasArchive.asset(out,second),note=try CanvasArchive.asset(out,"Project.txt"),initialNote=try CanvasArchive.asset(src,"Project.txt"),after=try Data(contentsOf:src)
        precondition(roundTrip==b && unchanged==b && note==initialNote && after==original);precondition((try? CanvasArchive.replacing(src,"no-such.png",with:b))==nil)
        print("PASS: ZIP list, selected PNG replacement, CRC re-read, untouched entry and text, unchanged source, and missing-target rejection")
    }
}
