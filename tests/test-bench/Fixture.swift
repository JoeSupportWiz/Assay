import Foundation
@main enum BenchFixture {
    static func main() throws {
        let suite="assay.bench.fixture."+UUID().uuidString;let d=UserDefaults(suiteName:suite)!;defer{d.removePersistentDomain(forName:suite)}
        func record(_ mode:String,_ v:String,_ obs:[BenchObservation]) -> BenchRecord { .init(engine:mode,version:v,observed:obs) }
        let old=record("iphone","17.4",[.init(check:.system,value:"17.4"),.init(check:.power,value:"off")]);let new=record("iphone","17.5",[.init(check:.system,value:"17.5")]);let demo=record("demo","17.5",[])
        precondition(new.compare(demo)==nil && new.compare(old)?.count==2 && new.compare(new)==[])
        var store=try BenchArchive.load(d);store.checks=[.vault,.system];for _ in 0..<22 {store.add(old)};store.add(new);try store.write(d);let back=try BenchArchive.load(d);precondition(back.history.count==20 && back.history.first==new && back.checks==[.vault,.system]);d.set(Data([255]),forKey:BenchArchive.key);precondition((try? BenchArchive.load(d))==nil)
        print("PASS: saved test bench selection, version diff, missing ≠ passing, source isolation, 20-sample retention, rejection of corrupt history")
    }
}
