import SwiftUI
import UniformTypeIdentifiers

private struct BuildIPADocument: FileDocument {
    static let ipa = UTType(filenameExtension:"ipa") ?? .data
    static var readableContentTypes:[UTType]{[ipa]}
    var data:Data
    init(_ bytes:Data){data=bytes}
    init(configuration:ReadConfiguration)throws{throw CocoaError(.fileReadUnsupportedScheme)}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}
struct SignetBuildLibrary:View {
    @Environment(\.theme) private var theme
    @State private var token=""
    @State private var builds:[SignetBuildRef]=[]
    @State private var selected:SignetBuildRef?
    @State private var verified:SignetVerifiedPayload?
    @State private var busy=false
    @State private var notice=""
    @State private var exporting=false
    @State private var sequence=UUID()
    private let client=SignetBuildClient()
    var body:some View {
        List {
            Section {
                SecureField("Repository read token",text:$token).textInputAutocapitalization(.never).autocorrectionDisabled(true).privacySensitive().disabled(busy)
                Button("List available builds",systemImage:"arrow.clockwise"){list()}.disabled(busy || token.isEmpty)
            } header:{Text("JoeSupportWiz / Assay")} footer:{Text("Use a fine-grained GitHub token restricted to this private repository with Actions: Read. Kept in memory on this screen only. No Apple login is needed. Listing sends a request to GitHub.")}.rowCard()
            if !builds.isEmpty {
                Section("Available artifacts") { ForEach(builds){ b in
                    Button { selected=b;verified=nil;notice="" } label:{HStack{VStack(alignment:.leading){Text("Run #\(String(b.run))");Text("\(b.branch) · \(b.sha.prefix(10))").font(.caption.monospaced()).foregroundStyle(.secondary)};Spacer();if selected?.id==b.id{Image(systemName:"checkmark")}}}.disabled(busy)
                }}.rowCard()
            }
            if let b=selected {
                Section {LabeledContent("Archive size",value:ByteCountFormatter.string(fromByteCount:Int64(b.size),countStyle:.file));Text(b.digest).font(.caption.monospaced()).textSelection(.enabled);Button("Download and verify",systemImage:"checkmark.shield"){download(b)}.disabled(busy || token.isEmpty)} header:{Text("Review this archive")} footer:{Text("Checks the GitHub workflow, source revision and archive SHA-256 before accepting the IPA. This does not establish an Apple signature or install anything.")}.rowCard()
            }
            if let verified {Section("Verified IPA"){LabeledContent("Version",value:"\(verified.version) (\(verified.build))");LabeledContent("Extensions",value:"\(verified.parts)");Text("IPA SHA-256: \(verified.digest)").font(.caption.monospaced()).textSelection(.enabled);Button("Save IPA to Files",systemImage:"square.and.arrow.down"){exporting=true}}.rowCard()}
            if busy || !notice.isEmpty{Section {HStack{if busy{ProgressView()};Text(notice)} }.rowCard()}
        }.themedList().navigationTitle("Assay builds").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented:$exporting,document:verified.map{BuildIPADocument($0.bytes)},contentType:BuildIPADocument.ipa,defaultFilename:"Assay-\(selected.map{String($0.sha.prefix(8))} ?? "unsigned")"){result in if case .success=result{notice="Saved. Open the file in Signet to inspect its app and extension before signing."}}
        .onChange(of:token){_,_ in builds=[];selected=nil;verified=nil;notice=""}
        .onDisappear {sequence=UUID();token="";builds=[];selected=nil;verified=nil;busy=false}
    }
    private func list(){let op=UUID(),key=token.trimmingCharacters(in:.whitespacesAndNewlines);sequence=op;selected=nil;verified=nil;busy=true;notice="Reading GitHub artifact metadata…";Task { do{let v=try await client.list(key);guard sequence==op else{return};builds=v;notice=v.isEmpty ? "No current, eligible unsigned IPA artifacts.":"Select a build to review it."}catch{guard sequence==op else{return};notice=(error as? BuildFetchError)?.rawValue ?? "Cannot list builds."};busy=false }}
    private func download(_ ref:SignetBuildRef){let op=UUID(),key=token.trimmingCharacters(in:.whitespacesAndNewlines);sequence=op;verified=nil;busy=true;notice="Verifying workflow and downloaded bytes…";Task { do{let v=try await client.fetch(ref,key:key);guard sequence==op else{return};verified=v;notice="Artifact integrity verified. Apple signing has not been checked."}catch{guard sequence==op else{return};notice=(error as? BuildFetchError)?.rawValue ?? "Cannot verify this archive. Nothing was exported."};busy=false }}
}
