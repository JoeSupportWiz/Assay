import SwiftUI
import UniformTypeIdentifiers

private struct TeamProfileDocument: FileDocument {
    static var readableContentTypes:[UTType] { [.data] };var data:Data
    init(_ data:Data){self.data=data}
    init(configuration:ReadConfiguration)throws{throw CocoaError(.fileReadUnsupportedScheme)}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}
@MainActor struct AppleTeamView: View {
    @State private var issuer="", keyID="", name="", bundle="", certificate="", phone="", message=""
    @State private var credential:TeamCredential?, inventory:TeamInventory?, review:TeamGrant?, exported:TeamProfileDocument?
    @State private var pick=false, busy=false, confirm=false, save=false
    @State private var generation=UUID()
    var body:some View {
        List {
            Section {
                if credential == nil {
                    TextField("Issuer ID (team UUID)",text:$issuer).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Key ID",text:$keyID).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Choose team API key (.p8)"){pick=true}.disabled(UUID(uuidString:issuer)==nil || keyID.count != 10 || busy)
                } else {
                    Button("Load team from Apple"){load()}.disabled(busy)
                    Button("Disconnect and forget key",role:.destructive){forget()}
                }
            } header:{Text("Developer team")} footer:{Text("Use a team App Store Connect API key with access to Certificates, Identifiers & Profiles. It stays in memory while this screen is open. Assay sends only a five-minute token to Apple, not the key itself. No Apple ID password.")}.rowCard()
            if busy {Section {ProgressView("Contacting Apple…")}.rowCard()}
            if !message.isEmpty {Section("Status"){Text(message)}.rowCard()}
            if let inv=inventory {
                Section {
                    LabeledContent("Explicit iOS app IDs",value:"\(inv.bundles.count)")
                    LabeledContent("Current development certificates",value:"\(inv.certs.count)")
                    LabeledContent("Enabled iOS devices",value:"\(inv.devices.count)")
                    if inv.limited {Text("Only the first 200 entries of each resource were loaded. Use the developer portal if a target is missing.")}
                } header:{Text("Team inventory")} footer:{Text("These records came from Apple. Selecting a certificate does not mean its private signing key is on this iPhone.")}.rowCard()
                Section {
                    TextField("New profile name",text:$name).autocorrectionDisabled()
                    choice("Target bundle ID",inv.bundles,$bundle);choice("Development certificate",inv.certs,$certificate);choice("Device",inv.devices,$phone)
                    Button("Review profile request") {
                        guard let g=grant(inv) else{return};review=g;confirm=true
                    }.disabled(grant(inv)==nil || busy || exported != nil)
                    if exported != nil {Button("Save returned profile to Files"){save=true};Button("Prepare another target"){exported=nil;name="";message=""}}
                } header:{Text("Development profile")} footer:{Text("Creates one profile for the selected app or extension and one registered device. Existing identifiers, capabilities and certificates are not changed. Repeat for another target if needed. This is provisioning, not IPA signing.")}.rowCard()
            }
        }
        .themedList().navigationTitle("Apple developer team").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented:$pick,allowedContentTypes:[.data]){res in
            guard case .success(let u)=res else{return};do{credential=try TeamCredential.load(url:u,issuer:issuer,keyID:keyID);message="Key loaded locally. No connection has been made."}catch{message=(error as? TeamError)?.localizedDescription ?? "Could not read the selected API key."}
        }
        .confirmationDialog("Create this profile in your Apple account?",isPresented:$confirm,titleVisibility:.visible){
            Button("Create development profile"){if let g=review,let inv=inventory{create(g,inv)}};Button("Cancel",role:.cancel){review=nil}
        } message:{if let g=review {Text("\(g.name)\nApp ID: \(g.bundle.title)\nCertificate: \(g.cert.title)\nDevice: \(g.device.title)\nMakes one change on Apple’s server. Nothing is installed.")}}
        .fileExporter(isPresented:$save,document:exported,contentType:.data,defaultFilename:"Assay-Development.mobileprovision"){r in if case .failure(let e)=r,(e as NSError).code != NSUserCancelledError {message="Couldn’t export the returned profile. It remains available until you disconnect."}}
        .onDisappear {forget()}
    }
    private func choice(_ label:String,_ items:[TeamItem],_ binding:Binding<String>) -> some View {Picker(label,selection:binding){Text("Choose…").tag("");ForEach(items){i in Text(i.expires.map{d in "\(i.title) · \(d.formatted(date:.abbreviated,time:.omitted)) · …\(i.id.suffix(4))"} ?? i.title).tag(i.id)}}}
    private func grant(_ inv:TeamInventory)->TeamGrant? {
        guard let b=inv.bundles.first(where:{$0.id==bundle}),let c=inv.certs.first(where:{$0.id==certificate}),let p=inv.devices.first(where:{$0.id==phone}) else{return nil};let g=TeamGrant(name:name,bundle:b,cert:c,device:p);return (try? g.body(in:inv))==nil ? nil:g
    }
    private func forget(){generation=UUID();credential=nil;inventory=nil;exported=nil;review=nil;busy=false;issuer="";keyID="";name="";bundle="";certificate="";phone="";message=""}
    private func load(){guard !busy,let c=credential else{return};let g=UUID();generation=g;busy=true;inventory=nil;review=nil;exported=nil;message="";Task{defer{if generation==g{busy=false}};do{let inv=try await TeamPortal(cred:c).inventory();guard generation==g else{return};inventory=inv;message="Team inventory loaded. No account changes."}catch{if generation==g{message=(error as? TeamError)?.localizedDescription ?? "Could not load team inventory."}}}}
    private func create(_ request:TeamGrant,_ inv:TeamInventory){guard !busy,let c=credential else{return};busy=true;review=nil;let g=UUID();generation=g;Task{defer{if generation==g{busy=false}};do{let data=try await TeamPortal(cred:c).create(request,in:inv);guard generation==g else{return};exported=TeamProfileDocument(data);message="Apple returned a development profile. Save it locally; it contains device and team identifiers."}catch{if generation==g{message=(error as? TeamError)?.localizedDescription ?? "Creation could not be verified. Check your team’s portal before retrying."}}}}
}
