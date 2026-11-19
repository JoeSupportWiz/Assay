import SwiftUI

@MainActor struct BenchView: View {
    @Environment(AppModel.self) private var model
    @State private var archive=BenchArchive()
    @State private var enabled=false
    @State private var running=false
    @State private var note=""
    private var current:[BenchRecord]{archive.history.filter{$0.engine==model.engine.mode.rawValue}}
    var body:some View {
        List {
            Section {
                Menu("Start from a setup card") {
                    Button("New iPhone"){save([.system,.power,.vault])}
                    Button("Developer setup"){save([.system,.changes,.vault])}
                    Button("Travel check"){save([.system,.power])}
                }
                ForEach(BenchCheck.allCases) { c in Toggle(c.rawValue,isOn:Binding(get:{archive.checks.contains(c)},set:{on in save(on ? archive.checks+[c] : archive.checks.filter{$0 != c})})) }
            } header:{Text("My checklist")} footer:{Text("Only the selected checks run. A check doesn’t start a backup, change a setting or contact a server.")}.rowCard().disabled(!enabled || running)
            Section {
                Button {Task{await run()}} label:{if running {ProgressView("Checking…")} else {Label("Run saved checklist",systemImage:"checklist")}}.disabled(running || !enabled || archive.checks.isEmpty)
                if !note.isEmpty{Text(note).font(.footnote)}
            }.rowCard()
            if let latest=current.first { Section {
                Text(latest.at,format:.dateTime.day().month().hour().minute().second())
                ForEach(latest.observed,id:\.check){o in LabeledContent(o.check.rawValue,value:o.value)}
                if current.count>1,let changes=latest.compare(current[1]) { DisclosureGroup("Compare with previous check") {
                    if latest.version != current[1].version {Text("The reported OS version changed. Recheck compatibility before using an old preset.")}
                    if changes.isEmpty {Text("No change in the recorded checks.")} else {ForEach(changes,id:\.self){Text(verbatim:$0)}}
                }}
            } header:{Text(latest.engine=="demo" ? "Latest · Demo" : "Latest · locally recorded")} footer:{Text("Up to 20 runs are kept across engines on this installation. Comparisons use the same engine, not a unique hardware identifier. An unselected check is not a passing result.")}.rowCard() }
        }.themedList().navigationTitle("Test bench").navigationBarTitleDisplayMode(.inline)
        .onAppear{do{archive=try .load(.standard);enabled=true}catch{enabled=false;note="Saved checks could not be read. Existing records have not been overwritten."}}
    }
    private func save(_ checks:[BenchCheck]) {var next=archive;next.checks=BenchCheck.allCases.filter{checks.contains($0)};do{try next.write(.standard);archive=next}catch{note="Could not save the checklist."}}
    private func run() async {
        guard enabled,!running else{return};running=true;defer{running=false};let g=model.engineGeneration,engine=model.engine, checks=archive.checks
        let snap=await engine.snapshot();guard g==model.engineGeneration else {note="Engine changed. Run the check again.";return}
        var obs=[BenchObservation]()
        for c in checks {let v:String;switch c {
        case .system:v=snap.osVersion
        case .power: v=["Low Power Mode","Thermal state"].map{name in name+": "+(snap.facts.first{$0.label==name}?.value ?? "unknown")}.joined(separator:" · ")
        case .changes:v=String(model.receipts.verifiedChangeCount(engine:engine.mode)) + " verified preference changes"
        case .vault:if engine.mode == .demo {v="Not read in Demo"} else {do{let hist=try await VaultStore.shared.history();v="\(hist.snapshots.count) saved · \(hist.unreadable) unreadable records (not a restore test)"}catch{v="Metadata unavailable"}}
        };obs.append(.init(check:c,value:v)) }
        guard g==model.engineGeneration else{note="Engine changed. The mixed sample was discarded.";return};var next=archive;next.add(.init(engine:engine.mode.rawValue,version:snap.osVersion,observed:obs));do{try next.write(.standard);archive=next;note="Saved a new check."}catch{note="Could not save the check."}
    }
}
