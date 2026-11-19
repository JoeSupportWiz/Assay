import SwiftUI
import UniformTypeIdentifiers

struct GildPresetFilesView:View {
    @Environment(AppModel.self) private var model
    @State private var title="My preset"
    @State private var pending:PortableEdits?
    @State private var pick=false
    @State private var save=false
    @State private var doc:StudioDataDocument?
    @State private var notice=""
    private var os:String { model.snapshot?.osVersion ?? UIDevice.current.systemVersion }
    var body:some View { List {
        Section { TextField("Preset name",text:$title);LabeledContent("Staged edits",value:String(model.tweaks.stagedCount));Button("Export staged changes as JSON") {do{doc=StudioDataDocument(try PortableEdits.export(model.tweaks.staged,name:title,os:os));save=true}catch{notice=error.localizedDescription}}.disabled(model.tweaks.stagedCount==0) } header:{Text("Build a preset")} footer:{Text("Choose values or removals in Gild first. Exported text edits contain the exact text you entered. No receipt history, device data or keys are included.")}.rowCard()
        Section {Button("Choose Assay preset"){pick=true}} header:{Text("Import locally")} footer:{Text("Imports can only name known catalogue entries. An import never writes a device setting or triggers a shortcut.")}.rowCard()
        if let p=pending {Section {Text(p.title).font(.headline);ForEach(p.edits,id:\.id){item in if let t=TweakCatalog.tweak(item.id){ VStack(alignment:.leading,spacing:4){Text(t.title);Text("\(model.tweaks.loaded ? (model.tweaks.current[t.id]?.display ?? "absent") : "unknown") → \(describe(item.value))").font(.caption.monospaced());Tag(style:t.tier.tag)} }};Button("Add these edits to staged changes"){do{let edits=try p.checked(os:os);for (t,v) in edits {model.tweaks.stage(t,value:v)};pending=nil;notice="Preset reviewed. \(model.tweaks.stagedCount) pending change(s) in Gild; nothing applied."}catch{pending=nil;notice=error.localizedDescription}};Button("Discard import",role:.cancel){pending=nil} } header:{Text("Review imported diff")} footer:{Text("Where IDs overlap, the imported edits replace your staged values. Other staged edits stay unchanged.")}.rowCard() }
        if !notice.isEmpty {Section("Status"){Text(notice)}.rowCard()}
    }.themedList().navigationTitle("Preset files").navigationBarTitleDisplayMode(.inline)
     .fileExporter(isPresented:$save,document:doc,contentType:.json,defaultFilename:"Assay-preset.json"){r in doc=nil;if case .success=r{notice="Preset saved."}else if case .failure(let e)=r,(e as NSError).code != NSUserCancelledError {notice="Could not save the preset."}}
     .fileImporter(isPresented:$pick,allowedContentTypes:[.json]){r in guard case .success(let u)=r else{return};pending=nil;notice="";do{let scope=u.startAccessingSecurityScopedResource();defer{if scope{u.stopAccessingSecurityScopedResource()}};let h=try FileHandle(forReadingFrom:u);defer{try? h.close()};let d=try h.read(upToCount:65537) ?? Data();pending=try PortableEdits.decode(d,os:os)}catch{notice=(error as? PortableEdits.Failure)?.localizedDescription ?? "Could not read the selected file."}}
    }
    private func describe(_ v:PortableEdits.Value)->String {switch v{case .remove:"Remove";case .flag(let b):b ? "On":"Off";case .number(let n):String(n);case .text(let s):s}}
}
