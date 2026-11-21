import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var t
    @Environment(\.dynamicTypeSize) private var typeSize
    private var demo: Bool { model.engine.mode == .demo }
    private var findings: [Finding] { model.findings.filter { $0.fix != nil } }
    private func go(_ route: LabRoute) { model.selectedTab = .lab; model.labPath = [route] }
    private func open(_ module: StudioModule) { model.selectedTab = .studio; model.studioPath = [.module(module)] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AssayCraftHeading(section: "Home", title: model.userName.isEmpty ? "Your workbench." : "Hey \(model.userName),", secondLine: "What are we making?")
                HStack(spacing: 7) {
                    Image(systemName: demo ? "square.stack.3d.up" : "iphone").accessibilityHidden(true)
                    Text(demo ? "Demo · sample device" : (model.snapshot.map { "This iPhone · iOS \($0.osVersion)" } ?? "This iPhone"))
                }.font(.subheadline.weight(.medium)).foregroundStyle(t.ink).padding(.horizontal, 12).padding(.vertical, 7).background(t.card,in:Capsule())
                let cols = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: typeSize >= .xxLarge ? 1 : 2)
                LazyVGrid(columns: cols, alignment: .leading, spacing: 12) {
                    Button { Task { await model.runCheck() } } label: { hero }.buttonStyle(.plain).disabled(model.checking)
                    Button { go(demo ? .fileVault : .usbHandoff) } label: { backup }.buttonStyle(.plain)
                }
                if let f=findings.first {
                    Button { if let id=f.symptomID { model.selectedTab = .lab; model.labPath = [.diagnose,.symptom(id)] } else { go(.diagnose) } } label: {
                        HStack(alignment:.top) { Image(systemName:"exclamationmark.circle"); VStack(alignment:.leading,spacing:3){ Text(demo ? "Sample finding" : "Needs attention").font(.caption.weight(.semibold));Text(f.title).font(.headline) };Spacer();Image(systemName:"chevron.right").accessibilityHidden(true) }.padding(14).foregroundStyle(t.ink).craftSurface(t.card,radius:t.tileRadius)
                    }.buttonStyle(.plain)
                }
                HStack { Text("Studio").font(.title2.bold()).foregroundStyle(t.ink); Spacer();Button("See all") { model.selectedTab = .studio; model.studioPath = [] } }
                LazyVGrid(columns: cols, spacing: 12) { ForEach([StudioModule.canvas, .gild],id:\.self){ m in Button { open(m) } label: { m.tile }.buttonStyle(.plain) } }
                VStack(alignment:.leading,spacing:4){
                    Button { go(.diagnose) } label: { Label("Diagnose a problem",systemImage:"magnifyingglass").frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,9) }
                    Divider(); Button { go(.history) } label: { Label("Undo history",systemImage:"clock.arrow.circlepath").frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,9) }
                }.font(.body).foregroundStyle(t.ink).padding(.horizontal,14).padding(.vertical,3).craftSurface(t.card,radius:t.tileRadius)
            }.padding(.horizontal,20).padding(.vertical,12).padding(.bottom,20)
        }.background(ThemedBackground()).navigationTitle("Home").navigationBarTitleDisplayMode(.inline).toolbar(.hidden,for:.navigationBar)
        .task { if model.lastCheck == nil { await model.runCheck() } }.refreshable { await model.runCheck() }
    }
    private var hero: some View {
        VStack(alignment:.leading,spacing:9){ AssayCraftGlyph(asset:"fold-device-check");Text(demo ? "Sample device check" : "Device check").font(.headline); if model.checking { ProgressView().tint(Palette.paper).accessibilityLabel("Checking") } else if let d=model.lastCheck { Text(d,style:.time).font(.title.bold()).monospacedDigit();Text("Last checked").font(.caption) } else {Text("Not checked").font(.body)};Spacer(minLength:2);Text("Run check →").font(.subheadline.bold()) }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading).padding(16).foregroundStyle(Palette.paper).craftSurface(Palette.ink,radius:t.cardRadius,plane:true).padding(.trailing,4).padding(.bottom,5)
    }
    private var backup: some View {
        VStack(alignment:.leading,spacing:9){ AssayCraftGlyph(asset:"fold-vault"); Text(demo ? "File Vault" : "USB backup").font(.headline);Text(demo ? "Selected files" : "With your Mac").font(.title3.bold());Text(demo ? "Save a file checkpoint." : "Hand off a request and review the receipt.").font(.subheadline);Spacer(minLength:2);Text(demo ? "Open Vault →" : "Open handoff →").font(.subheadline.bold()) }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading).padding(16).foregroundStyle(Palette.ink).craftSurface(Palette.butter,radius:t.cardRadius)
    }
}
