import Foundation
import CoreFoundation

/// A read-only, bounded projection of the embedded signature. Reading bytes is not signature verification.
struct SignetBinaryEvidence: Hashable, Sendable {
    enum State: String, Sendable { case xml, unsigned, signedWithoutXML, unsupported, unavailable }
    let state: State
    var values: [String:String] = [:]
    var hasDER = false
    var summary: String {
        switch state {
        case .xml: return "\(values.count) XML entitlement keys read" + (hasDER ? " · DER also present" : "")
        case .unsigned: return "No code-signature command in this executable"
        case .signedWithoutXML: return hasDER ? "DER only · not decoded" : "Signature contains no XML entitlement slot"
        case .unsupported: return "Unsupported or malformed executable/signature"
        case .unavailable: return "Executable unavailable or outside inspection limit"
        }
    }
    var observed: Bool { [.xml,.unsigned,.signedWithoutXML].contains(state) }
    static let unavailable = Self(state:.unavailable)

    /// Thin, little-endian Mach-O 64 only. Refuse malformed offsets and duplicate slots; never load the executable.
    static func inspect(_ data: Data) -> Self {
        let b = Array(data), bad = Self(state:.unsupported)
        guard b.count >= 32 else { return bad }
        func num(_ p:Int,_ big:Bool=false)->Int {
            if big { return Int(b[p])<<24 | Int(b[p+1])<<16 | Int(b[p+2])<<8 | Int(b[p+3]) }
            return Int(b[p]) | Int(b[p+1])<<8 | Int(b[p+2])<<16 | Int(b[p+3])<<24
        }
        guard num(0)==0xfeedfacf, num(16)<=4096 else {return bad}
        let end=32+num(20);guard end<=b.count else{return bad}
        var cursor=32, region: Range<Int>?
        for _ in 0..<num(16) {
            guard cursor+8<=end else{return bad}
            let length=num(cursor+4);guard length>=8,cursor+length<=end else{return bad}
            if num(cursor)==0x1d {
                guard length==16,region==nil else{return bad};let a=num(cursor+8),size=num(cursor+12)
                guard a>=end,size>=12,a+size<=b.count else{return bad};region=a..<(a+size)
            }
            cursor+=length
        }
        guard cursor==end else{return bad};guard let bounds=region else{return Self(state:.unsigned)}
        let a=bounds.lowerBound, size=num(a+4,true), count=num(a+8,true)
        guard num(a,true)==0xfade0cc0,count<=1024,size>=12+8*count,size<=bounds.count else{return bad}
        var xml:Range<Int>?,seen=Set<Int>(),der=false
        for i in 0..<count {
            let p=a+12+8*i,kind=num(p,true),offset=num(p+4,true)
            guard seen.insert(kind).inserted,offset>=12+8*count,offset+8<=size else{return bad}
            let length=num(a+offset+4,true);guard length>=8,offset+length<=size else{return bad}
            if kind==5 {guard num(a+offset,true)==0xfade7171,length<=262_152 else{return bad};xml=(a+offset+8)..<(a+offset+length)}
            if kind==7 {guard num(a+offset,true)==0xfade7172 else{return bad};der=true}
        }
        guard let xml else{return Self(state:.signedWithoutXML,hasDER:der)}
        guard let obj=try? PropertyListSerialization.propertyList(from:Data(b[xml]),options:[],format:nil),let ent=obj as? [String:Any],ent.count<=256 else{return bad}
        var result=[String:String]()
        for (k,v) in ent {
            guard k.utf8.count<=256,!k.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else{return bad}
            if let str=v as? String {result[k]=String(str.prefix(512))}
            else if let ar=v as? [String] {result[k]=ar.prefix(8).map{String($0.prefix(128))}.joined(separator:", ")+(ar.count>8 ? " …":"")}
            else if let n=v as? NSNumber {result[k]=CFGetTypeID(n)==CFBooleanGetTypeID() ? (n.boolValue ? "true":"false"):n.stringValue}
            else {result[k]="Structured value"}
        }
        return Self(state:.xml,values:result,hasDER:der)
    }
}
