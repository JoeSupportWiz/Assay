import SwiftUI
import UniformTypeIdentifiers

private enum CardPalette:String,CaseIterable {case dune="Dune",fjord="Fjord",iris="Iris"
    var colors:[Color]{switch self{case .dune:[Color(hex:0x9C463D),Color(hex:0x302C41)];case .fjord:[Color(hex:0x176564),Color(hex:0x182C49)];case .iris:[Color(hex:0x634399),Color(hex:0x20213B)]}}
}
private struct StudioCardFace:View {
    let title:String,caption:String, palette:CardPalette, image:CGImage?, zoom:Double, x:Double,y:Double, motif:Bool
    var body:some View { GeometryReader {g in
        let w=g.size.width,h=g.size.height
        ZStack(alignment:.bottomLeading){
            LinearGradient(colors:palette.colors,startPoint:.topLeading,endPoint:.bottomTrailing)
            if let image {
                let scale=max(w/CGFloat(image.width),h/CGFloat(image.height))*zoom
                let iw=CGFloat(image.width)*scale, ih=CGFloat(image.height)*scale
                Image(decorative:image,scale:1).resizable().frame(width:iw,height:ih).position(x:w/2+(iw-w)/2*x,y:h/2+(ih-h)/2*y)
            }
            if motif {
                SwiftUI.Canvas { c,s in for i in 0..<13 {let k=CGFloat(i)/12;var p=Path();p.move(to:.init(x:s.width*(0.05+k*0.8),y:0));p.addQuadCurve(to:.init(x:s.width*1.08,y:s.height*(0.26+k*0.7)),control:.init(x:s.width*(0.88-k*0.24),y:s.height*(0.06+k*0.56)));c.stroke(p,with:.color(.white.opacity(0.21)),lineWidth:w/540)} }.accessibilityHidden(true)
            }
            LinearGradient(colors:[.clear,.black.opacity(0.44)],startPoint:.center,endPoint:.bottom)
            VStack(alignment:.leading,spacing:h*0.025){Text(verbatim:title).font(.system(size:w*0.088,weight:.semibold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.48);Text(verbatim:caption).font(.system(size:w*0.035,weight:.medium)).lineLimit(2).minimumScaleFactor(0.7)}.foregroundStyle(.white).padding(w*0.065)
        }.frame(width:w,height:h).clipped()
    } }
}
@MainActor struct CardArtRootView:View {
    @AppStorage("card-art.title") private var title="Field Notes"; @AppStorage("card-art.subtitle") private var caption="No. 01  /  Dusk series"
    @AppStorage("card-art.palette") private var palette=CardPalette.iris; @AppStorage("card-art.motif") private var motif=true
    @State private var image: CGImage?
    @State private var zoom=1.0
    @State private var x=0.0
    @State private var y=0.0
    @State private var picking=false
    @State private var exporting=false
    @State private var busy=false
    @State private var info=""
    @State private var doc:StudioDataDocument?
    private var face:some View {StudioCardFace(title:String(title.prefix(64)),caption:String(caption.prefix(100)),palette:palette,image:image,zoom:zoom,x:x,y:y,motif:motif)}
    var body:some View {
        List {
            Section {face.aspectRatio(1.6,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:14)).accessibilityLabel("Card artwork preview")}.listRowBackground(Color.clear)
            Section("Design") {TextField("Title",text:$title).onChange(of:title){_,v in if v.count>64{title=String(v.prefix(64))}};TextField("Caption",text:$caption).onChange(of:caption){_,v in if v.count>100{caption=String(v.prefix(100))}};Picker("Palette",selection:$palette){ForEach(CardPalette.allCases,id:\.self){Text($0.rawValue).tag($0)}};Toggle("Contour lines",isOn:$motif)}.rowCard()
            Section { Button(image == nil ? "Choose artwork from Files":"Replace artwork"){picking=true}.disabled(busy)
                if image != nil {Text("Crop · \(zoom, specifier:"%.1f")×");Slider(value:$zoom,in:1...3).accessibilityLabel("Crop zoom");Slider(value:$x,in:-1...1).accessibilityLabel("Horizontal framing");Slider(value:$y,in:-1...1).accessibilityLabel("Vertical framing");Button("Remove image"){image=nil;x=0;y=0;zoom=1}}
            } header:{Text("Image")} footer:{Text("The starter design is generated on device. Selected artwork is downsampled locally and used only in this editing session.")}.rowCard()
            Section {Button("Export 1600 × 1000 PNG"){export()}.disabled(busy);if !info.isEmpty {Text(info).foregroundStyle(.secondary)}} footer:{Text("A design file only. This does not issue a Wallet pass or change an Apple Pay card.")}.rowCard()
        }.themedList().navigationTitle("Cards").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented:$picking,allowedContentTypes:[.image]){res in guard case .success(let u)=res else{return};busy=true;Task {defer{busy=false};do{image=try await Task.detached(priority:.userInitiated){try StudioArtwork.readImage(u)}.value;zoom=1;x=0;y=0;info=""}catch{info="That image could not be opened. Pick a supported image of up to 20 MiB."}}}
        .fileExporter(isPresented:$exporting,document:doc,contentType:.png,defaultFilename:"Assay-card-art.png"){r in doc=nil;if case .success=r {info="PNG exported."}else if case .failure(let e)=r,(e as NSError).code != NSUserCancelledError {info="Export failed. Try another folder."}}
    }
    private func export(){let renderer=ImageRenderer(content:face.frame(width:1600,height:1000).environment(\.layoutDirection,.leftToRight));renderer.scale=1;renderer.isOpaque=true;guard let im=renderer.cgImage,let d=try? StudioArtwork.png(im) else {info="Couldn’t render the artwork.";return};doc=StudioDataDocument(d);exporting=true}
}
