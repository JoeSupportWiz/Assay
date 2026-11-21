import Foundation

/// Only replaces the literal `true` in two known v2 preset entries. No re-encoding of unrelated values.
struct DisplayPresetCopy {
    enum Issue: String, LocalizedError { case invalid = "Choose a valid GoldenNugget v2 JSON preset (up to 2 MiB).", ambiguous = "This preset has duplicate fields or an unexpected display entry. Nothing was changed."
        var errorDescription: String? { rawValue }
    }
    static let clock = "SBShowStatusBarOverridesForRecording", line = "SBShowAuthenticationEngineeringUI"
    static let keys = [clock, line], limit = 2*1024*1024
    let data: Data, changed: [String], present: [String]
    static func review(_ data: Data) throws -> Self {
        guard !data.isEmpty, data.count <= limit, data.first == 123 || [9,10,13,32].contains(data.first!),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
              let meta = root["metadata"] as? [String: Any], let version = meta["version"] as? NSNumber, version.stringValue == "2",
              let entries = root["tweaks"] as? [String:Any] else { throw Issue.invalid }
        for key in keys where entries[key] != nil { guard (entries[key] as? [String:Any])?["enabled"] != nil else { throw Issue.ambiguous } }
        var s = Scanner(bytes: Array(data)); try s.value([],0);s.space();guard s.i==s.bytes.count else { throw Issue.invalid }
        var result=data
        for range in s.ranges.values.sorted(by:{$0.lowerBound>$1.lowerBound}) { result.replaceSubrange(range,with:"false".utf8) }
        return Self(data:result,changed:keys.filter{s.ranges[$0] != nil},present:keys.filter{entries[$0] != nil})
    }
    private struct Scanner {
        let bytes:[UInt8];var i=0, ranges:[String:Range<Int>]=[:]
        mutating func space(){while i<bytes.count && [9,10,13,32].contains(bytes[i]){i+=1}}
        mutating func tokenString() throws -> Range<Int>{guard i<bytes.count,bytes[i]==34 else{throw Issue.invalid};let start=i;i+=1;while i<bytes.count {let x=bytes[i];i+=1;if x==34{return start..<i};if x==92{i+=1}};throw Issue.invalid}
        mutating func take(_ c:UInt8) throws{space();guard i<bytes.count,bytes[i]==c else{throw Issue.invalid};i+=1}
        mutating func value(_ path:[String],_ depth:Int) throws {
            space();guard depth<64,i<bytes.count else{throw Issue.invalid}
            if path.count==3,path[0]=="tweaks",DisplayPresetCopy.keys.contains(path[1]),path[2]=="enabled" {
                let start=i;if bytes[i...].starts(with:"true".utf8){i+=4;ranges[path[1]]=start..<i;return};if bytes[i...].starts(with:"false".utf8){i+=5;return};throw Issue.ambiguous
            }
            switch bytes[i] {
            case 123:
                i+=1;space();if i<bytes.count,bytes[i]==125{i+=1;return};var seen=Set<String>()
                while true {space();let k=try tokenString();guard let key=try? JSONDecoder().decode(String.self,from:Data(bytes[k])), seen.insert(key).inserted else{throw Issue.ambiguous};try take(58);try value(path+[key],depth+1);space();guard i<bytes.count else{throw Issue.invalid};if bytes[i]==125{i+=1;return};try take(44)}
            case 91:
                i+=1;space();if i<bytes.count,bytes[i]==93{i+=1;return};while true{try value(path+["[]"],depth+1);space();guard i<bytes.count else{throw Issue.invalid};if bytes[i]==93{i+=1;return};try take(44)}
            case 34:_=try tokenString()
            default: let start=i;while i<bytes.count && ![9,10,13,32,44,93,125].contains(bytes[i]){i+=1};guard i>start else{throw Issue.invalid}
            }
        }
    }
}
