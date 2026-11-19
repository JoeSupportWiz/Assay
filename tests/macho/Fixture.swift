import Foundation
@main enum MachFixture {
    static func main() throws {
        func le(_ n:Int)->[UInt8]{(0..<4).map{UInt8(truncatingIfNeeded:n>>($0*8))}}
        func be(_ n:Int)->[UInt8]{Array(le(n).reversed())}
        func image(blob:[UInt8]?) -> Data {
            var b=le(0xfeedfacf)+le(0x0100000c)+le(0)+le(2);b+=le(blob==nil ? 0:1)+le(blob==nil ? 0:16)+le(0)+le(0)
            if let blob {b+=le(0x1d)+le(16)+le(48)+le(blob.count)+blob};return Data(b)
        }
        let xml=Array(try PropertyListSerialization.data(fromPropertyList:["fixture.flag":true,"fixture.group":["group.fixture"]] as [String:Any],format:.xml,options:0));let item=be(0xfade7171)+be(8+xml.count)+xml
        let signed=be(0xfade0cc0)+be(20+item.count)+be(1)+be(5)+be(20)+item
        let result=SignetBinaryEvidence.inspect(image(blob:signed));precondition(result.state == .xml && result.values["fixture.flag"]=="true" && result.values["fixture.group"]=="group.fixture")
        precondition(SignetBinaryEvidence.inspect(image(blob:nil)).state == .unsigned)
        precondition(SignetBinaryEvidence.inspect(Data(repeating:0,count:31)).state == .unsupported)
        var broken=signed;broken[19]=200;precondition(SignetBinaryEvidence.inspect(image(blob:broken)).state == .unsupported)
        let der=be(0xfade0cc0)+be(28)+be(1)+be(7)+be(20)+be(0xfade7172)+be(8)
        let d=SignetBinaryEvidence.inspect(image(blob:der));precondition(d.state == .signedWithoutXML && d.hasDER)
        print("PASS: binary entitlement XML, bare unsigned executable, unsupported/malformed bounds and explicit DER-only state")
    }
}
