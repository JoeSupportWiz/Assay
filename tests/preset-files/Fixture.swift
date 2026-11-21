import Foundation
// Minimal fixtures for unrelated UI-only types. Use the production JSON format and validator below.
enum PlistValue:Hashable {case bool(Bool),int(Int),double(Double),string(String)}
enum Tier: String,Comparable {case reversible,caution,experimental;static func <(a:Tier,b:Tier)->Bool{[Self.reversible,.caution,.experimental].firstIndex(of:a)! < [Self.reversible,.caution,.experimental].firstIndex(of:b)!}}
struct PrefKey:Hashable{var domain:String;var key:String}
@main enum Fixture {
    static func main() throws {
        let t="Fixture",os="27.3", toggle="SBHideLowPowerAlerts",n="SBMinimumLockscreenIdleTime",txt="LockScreenFootnote"
        var map:[String:PlistValue?]=[toggle:.bool(true),n:.int(60),txt:.string("Test only")];map["SBNeverBreadcrumb"] = .some(nil)
        let d=try PortableEdits.export(map,name:t,os:os);let p=try PortableEdits.decode(d,os:os);let matched=try p.checked(os:os);precondition(matched.count==4 && matched.contains(where:{$0.0.id=="SBNeverBreadcrumb" && $0.1==nil}))
        func rejects(_ edits:[PortableEdits.Edit],_ label:String,os:String="27.3") {let x=PortableEdits(format:PortableEdits.schema,title:label,edits:edits);precondition((try? x.checked(os:os))==nil)}
        rejects([.init(id:"not-in-catalogue",value:.flag(true))],t);rejects([.init(id:n,value:.number(61))],t);rejects([.init(id:n,value:.number(999))],t);rejects([.init(id:toggle,value:.text("bad type"))],t);rejects([.init(id:toggle,value:.remove),.init(id:toggle,value:.flag(true))],t);rejects([.init(id:txt,value:.text("a\nb"))],t);rejects([.init(id:txt,value:.text(String(repeating:"x",count:257)))],t);rejects([.init(id:"SBShowStatusBarOverridesForRecording",value:.flag(true))],t,os:"17.0");rejects([],t);rejects([.init(id:toggle,value:.remove)]," ");precondition((try? PortableEdits.decode(Data(repeating:0,count:65537),os:os))==nil)
        print("PASS: valid preset round-trip, explicit removal and 11 rejection cases; no engine calls")
    }
}
