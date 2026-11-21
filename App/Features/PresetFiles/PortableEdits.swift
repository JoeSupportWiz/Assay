import Foundation

/// Versioned data only. Imports cannot choose domains, paths, engines, checks, or commands.
struct PortableEdits: Codable {
    enum Value: Codable { case remove, flag(Bool), number(Int), text(String) }
    struct Edit: Codable { let id:String; let value:Value }
    let format:String; let title:String; let edits:[Edit]
    static let schema="assay.catalogue-preset.v1"
    enum Failure:LocalizedError { case invalid, unknown, unsupported, wrongValue
        var errorDescription:String? {switch self {case .invalid:"Not a valid Assay preset (64 KiB and 64 edits maximum).";case .unknown:"Unknown or duplicate catalogue ID. Nothing was staged.";case .unsupported:"A tweak is outside the current iOS range. Nothing was staged.";case .wrongValue:"A value is the wrong type, length, range or step for its catalogue entry."}}
    }
    static func decode(_ d:Data, os:String)throws->Self {
        guard (1...65536).contains(d.count),let p=try? JSONDecoder().decode(Self.self,from:d) else {throw Failure.invalid}; _ = try p.checked(os:os);return p
    }
    func checked(os:String)throws->[(Tweak,PlistValue?)] {
        guard format==Self.schema,(1...64).contains(edits.count),(1...80).contains(title.utf8.count),title.trimmingCharacters(in:.whitespacesAndNewlines) != "", !title.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else {throw Failure.invalid}
        var seen=Set<String>();return try edits.map { item in
            guard seen.insert(item.id).inserted, let t=TweakCatalog.tweak(item.id) else {throw Failure.unknown}
            guard t.availability(osVersion:os).isSupported else {throw Failure.unsupported}
            let v:PlistValue?
            switch (t.kind,item.value) {
            case (_, .remove):v=nil
            case (.toggle,.flag(let flag)): guard flag else {throw Failure.wrongValue};v = .bool(true)
            case let (.number(lo,hi,step,_),.number(n)):
                let val=Double(n);guard step>0,val>=lo,val<=hi,abs((val-lo)/step-((val-lo)/step).rounded())<0.000001 else {throw Failure.wrongValue};v = .int(n)
            case (.text,.text(let s)):guard !s.isEmpty,s.utf8.count<=256,!s.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else {throw Failure.wrongValue};v = .string(s)
            default: throw Failure.wrongValue
            }
            return(t,v)
        }
    }
    static func export(_ map:[String:PlistValue?], name:String, os:String)throws->Data {
        let edits=try map.sorted{$0.key<$1.key}.map {id,value -> Edit in
            let v:Value
            switch value {case nil:v = .remove; case .bool(true)?:v = .flag(true);case .int(let n)?:v = .number(n);case .string(let s)?:v = .text(s);default:throw Failure.wrongValue};return Edit(id:id,value:v)
        }
        let p=Self(format:schema,title:name,edits:edits); _ = try p.checked(os:os);let e=JSONEncoder();e.outputFormatting=[.sortedKeys,.prettyPrinted]; let d=try e.encode(p);guard d.count<=65536 else{throw Failure.invalid};return d
    }
}
