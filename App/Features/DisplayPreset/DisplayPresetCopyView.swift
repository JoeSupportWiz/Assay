import SwiftUI
import UniformTypeIdentifiers

struct DisplayPresetCopyView: View {
    @State private var review: DisplayPresetCopy?
    @State private var picking = false, saving = false, busy = false
    @State private var note: String?
    var body: some View {
        List {
            Section { Button("Choose exported preset…") { review=nil; note=nil; picking=true }.disabled(busy) } header: { Text("GoldenNugget preset") } footer: { Text("Choose an exported v2 preset or autosave.json in Files. Assay checks only the recording clock override and the red/green unlock indicator. It never opens another app’s private data.") }.rowCard()
            if let review {
                Section("In this file") {
                    ForEach(DisplayPresetCopy.keys,id:\.self) { key in
                        VStack(alignment:.leading,spacing:3){Text(key == DisplayPresetCopy.clock ? "Recording clock override" : "Red/green unlock line");Text(review.changed.contains(key) ? "Enabled → off in the new copy" : (review.present.contains(key) ? "Already off" : "Not in this preset")).font(.footnote).foregroundStyle(.secondary)}
                    }
                    if !review.changed.isEmpty { Button("Save a separate copy…") { saving=true }.disabled(busy) }
                }.rowCard()
            }
            if busy { ProgressView() }; if let note { Text(note).accessibilityLabel(note) }
            Section { Text("This edits a file, not the iPhone. Keep the original. Use the new copy instead of the old preset if you want these switches off in future. It does not undo an earlier system change. Review any other selections separately.") }.rowCard()
        }.themedList().navigationTitle("Display preset").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented:$picking,allowedContentTypes:[.json],allowsMultipleSelection:false){ res in
            guard case let .success(urls)=res, let u=urls.first else{return};busy=true
            Task { @MainActor in defer{busy=false};do { review=try await Task.detached(priority:.userInitiated){let access=u.startAccessingSecurityScopedResource();defer{if access{u.stopAccessingSecurityScopedResource()}}; guard u.isFileURL,try u.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile==true else{throw DisplayPresetCopy.Issue.invalid};let h=try FileHandle(forReadingFrom:u);defer{try? h.close()};var data=Data();while data.count<=DisplayPresetCopy.limit {guard let block=try h.read(upToCount:min(65536,DisplayPresetCopy.limit+1-data.count)),!block.isEmpty else{break};data.append(block)};return try DisplayPresetCopy.review(data)}.value; if review?.changed.isEmpty == true {note="Neither switch needs changing in this file."} }catch let e as DisplayPresetCopy.Issue {note=e.localizedDescription} catch {note="Couldn’t read that file. The original was not changed."} }
        }
        .background(Color.clear.fileImporter(isPresented:$saving,allowedContentTypes:[.folder]){ res in
            guard case let .success(folder)=res,let r=review else{return};busy=true
            Task { @MainActor in defer{busy=false};do {let name=try await Task.detached(priority:.userInitiated){let access=folder.startAccessingSecurityScopedResource();defer{if access{folder.stopAccessingSecurityScopedResource()}};let dest=folder.appendingPathComponent("Assay-display-off-\(UUID().uuidString.prefix(8)).json");try r.data.write(to:dest,options:.withoutOverwriting);guard try Data(contentsOf:dest)==r.data else{throw CocoaError(.fileReadCorruptFile)};return dest.lastPathComponent}.value;note="Saved and read back \(name). Your original and phone settings were not changed."}catch{note="Could not verify a new copy in that folder. Check Files; the original was not overwritten."} }
        })
    }
}
