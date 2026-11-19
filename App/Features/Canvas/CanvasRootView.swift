import SwiftUI
import UniformTypeIdentifiers

@MainActor struct CanvasRootView: View {
    @State private var project: URL?
    @State private var index: CanvasIndex?
    @State private var selected: String?
    @State private var preview: CGImage?
    @State private var originalSize: CGSize?
    @State private var replacement: Data?
    @State private var choosing = false
    @State private var chooseLayer = false
    @State private var busy = false
    @State private var exporting = false
    @State private var document: StudioDataDocument?
    @State private var message = ""
    @State private var search = ""
    @State private var validTask=UUID()
    @State private var defaultName="Edited.tendies"
    private var images:[String] { (index?.images ?? []).filter {search.isEmpty || $0.localizedCaseInsensitiveContains(search)} }
    var body: some View {
        List {
            Section {
                Button("Open .tendies or ZIP from Files"){chooseLayer=false;choosing=true}.disabled(busy)
                Button("Explore original sample artwork") { if let url=Bundle.main.url(forResource:"AssayCanvasSample",withExtension:"zip"){open(url)} else {message="Sample file unavailable."} }.disabled(busy)
                if let i=index {LabeledContent("Project",value:project?.lastPathComponent ?? "Archive");LabeledContent("Files · images · CAML",value:"\(i.fileCount) · \(i.images.count) · \(i.camlCount)")}
            } header:{Text("Wallpaper project")} footer:{Text("Inspect an archive locally. No project scripts or animations are executed. The included art sample is not a system wallpaper installation.")}.rowCard()
            if busy {Section {ProgressView("Reading artwork…")}.rowCard()};if !message.isEmpty{Section("Status"){Text(message)}.rowCard()}
            if let preview,let selected {
                Section {
                    Image(decorative:preview,scale:1).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:230).accessibilityLabel("Selected artwork")
                    Text(verbatim:(selected as NSString).lastPathComponent).font(.headline)
                    if let s=originalSize {LabeledContent("Layer dimensions",value:"\(Int(s.width)) × \(Int(s.height))")}
                    if CanvasIndex.ext(selected)=="png" {
                        Button("Choose replacement artwork"){chooseLayer=true;choosing=true}.disabled(busy)
                        if replacement != nil {Button("Discard replacement"){load(selected)}.disabled(busy);Button("Export edited project copy"){exportProject()}.disabled(busy)}
                    }
                } header:{Text(replacement == nil ? "Selected layer":"Replacement preview")} footer:{Text("Replacement PNGs are centre-cropped to the original pixel dimensions. Export to a NEW filename. The source is not edited by Assay.")}.rowCard()
            }
            if let i=index {Section("Image layers (\(i.images.count))") {
                if i.images.isEmpty{Text("No supported raster images found.")}
                ForEach(images,id:\.self){n in Button { load(n) } label:{VStack(alignment:.leading){Text(verbatim:(n as NSString).lastPathComponent);Text(verbatim:n).font(.caption2).lineLimit(2).foregroundStyle(.secondary)}}.disabled(busy)}
            }.rowCard()}
        }.themedList().navigationTitle("Canvas").navigationBarTitleDisplayMode(.inline).searchable(text:$search,prompt:"Filter image layers")
        .fileImporter(isPresented:$choosing,allowedContentTypes:chooseLayer ? [.image]:[.data]) { res in guard case .success(let url)=res else {return};if chooseLayer {replace(url)} else {open(url)} }
        .fileExporter(isPresented:$exporting,document:document,contentType:.data,defaultFilename:defaultName){r in document=nil;if case .success=r {message="Edited archive exported. Check it in your wallpaper app; Assay hasn’t tested system playback."} else if case .failure(let e)=r,(e as NSError).code != NSUserCancelledError {message="The edited copy could not be exported."}}
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-canvasSample"),let u=Bundle.main.url(forResource:"AssayCanvasSample",withExtension:"zip"){open(u)} }
        .onDisappear {validTask=UUID();busy=false}
    }
    private func open(_ url:URL){let token=UUID();validTask=token;busy=true;selected=nil;replacement=nil;preview=nil;project=nil;index=nil;message="";search=""
        Task{do {let i=try await Task.detached {try CanvasArchive.inspect(url)}.value;guard validTask==token else{return};project=url;index=i;busy=false;if let first=i.images.first{load(first)} } catch {failed(token,error)}}
    }
    private func load(_ name:String){guard let url=project else{return};let token=UUID();validTask=token;busy=true;selected=nil;replacement=nil;preview=nil;originalSize=nil;message=""
        Task{do {let (im,w,h)=try await Task.detached { let d=try CanvasArchive.asset(url,name);let (w,h)=try StudioArtwork.dimensions(d);return (try StudioArtwork.readBytes(d,pixels:1200),w,h) }.value;guard validTask==token else{return};originalSize=CGSize(width:w,height:h);preview=im;selected=name;busy=false }catch{failed(token,error)}}
    }
    private func replace(_ url:URL){guard let s=originalSize else{return};let token=UUID();validTask=token;busy=true;message=""
        Task{do{let (d,im)=try await Task.detached {let a=try StudioArtwork.readImage(url,pixels:Int(max(s.width,s.height)));let png=try StudioArtwork.fittedPNG(a,width:Int(s.width),height:Int(s.height));guard png.count<=CanvasIndex.fileCap else{throw CanvasFailure.limit};return (png,try StudioArtwork.readBytes(png,pixels:1200))}.value;guard validTask==token else{return};replacement=d;preview=im;busy=false }catch{failed(token,error)}}
    }
    private func exportProject(){guard let u=project,let n=selected,let d=replacement else{return};let token=UUID();validTask=token;busy=true;message=""
        Task{do{let data=try await Task.detached {try CanvasArchive.replacing(u,n,with:d)}.value;guard validTask==token else{return};document=StudioDataDocument(data);defaultName=u.deletingPathExtension().lastPathComponent+"-edited."+(u.pathExtension.lowercased()=="tendies" ? "tendies":"zip");busy=false;exporting=true}catch{failed(token,error)}}
    }
    private func failed(_ token:UUID,_ error:Error){guard validTask==token else{return};busy=false;message=(error as? CanvasFailure)?.localizedDescription ?? "Could not read or export this layer or archive. Choose a local, unencrypted ZIP-format project with supported raster images."}
}
