import Foundation

enum BenchCheck:String,CaseIterable,Codable,Hashable,Identifiable {
    case system="System version", power="Power & temperature", vault="File checkpoints", changes="Verified preferences"
    var id:String {rawValue}
}
struct BenchObservation: Codable,Equatable { let check:BenchCheck, value:String }
struct BenchRecord:Codable,Identifiable,Equatable {
    let id:UUID, at:Date, engine:String, version:String
    let observed:[BenchObservation]
    init(engine:String,version:String,observed:[BenchObservation],at:Date=Date()){self.id=UUID();self.at=at;self.engine=engine;self.version=version;self.observed=observed}
    func compare(_ old:Self) -> [String]? {
        guard engine==old.engine else {return nil}
        return BenchCheck.allCases.compactMap { c in
            let a=old.observed.first{$0.check==c}?.value,b=observed.first{$0.check==c}?.value
            guard a != b else{return nil};return "\(c.rawValue): \(a ?? "not checked") → \(b ?? "not checked")"
        }
    }
}
struct BenchArchive:Codable {
    static let key="assay.local-bench.v1"
    var checks=[BenchCheck.system,.power];var history=[BenchRecord]()
    enum Problem:Error {case unreadable}
    static func load(_ defaults:UserDefaults) throws -> Self {
        guard let data=defaults.data(forKey:key) else {return .init()};guard data.count<=256*1024,let v=try? JSONDecoder().decode(Self.self,from:data),v.history.count<=20,Set(v.checks).count==v.checks.count else {throw Problem.unreadable};return v
    }
    mutating func add(_ record:BenchRecord){ history.insert(record,at:0);history=Array(history.prefix(20)) }
    func write(_ defaults:UserDefaults)throws {let d=try JSONEncoder().encode(self);guard d.count<=256*1024 else {throw Problem.unreadable};defaults.set(d,forKey:Self.key)}
}
