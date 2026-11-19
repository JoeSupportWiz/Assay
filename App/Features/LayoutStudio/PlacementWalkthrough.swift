import SwiftUI

/// People place these items in SpringBoard themselves. Check marks are their observations, not device read-back.
struct PlacementWalkthrough: View {
    let snapshot: LayoutSnapshot
    @State private var checked = Set<Int>()
    @State private var loaded = false
    private var key: String { "assay.layout.progress." + snapshot.id.uuidString }
    private var cells: [(Int,String)] {
        LayoutPlacement(snapshot.recipe).cells.enumerated().compactMap { index, cell in
            if case .app(let name) = cell {return (index,name)}; return nil
        }
    }
    var body: some View {
        List {
            Section { LabeledContent("Confirmed by you", value: "\(checked.count) of \(cells.count)") } footer:{Text("This list records what you confirm. It does not read or rearrange the Home Screen.")}
            LayoutPreviewSections(recipe:snapshot.recipe)
            Section("Manual placement") { ForEach(cells, id:\.0) { index,name in
                Toggle(isOn: Binding(get:{checked.contains(index)},set:{on in if on {checked.insert(index)} else {checked.remove(index)}; UserDefaults.standard.set(Array(checked).sorted(),forKey:key)})) {
                    VStack(alignment:.leading){Text(verbatim:name);Text("Row \(index/4+1), column \(index%4+1)").font(.caption).foregroundStyle(.secondary)}
                }
            }}
        }.themedList().navigationTitle(snapshot.recipe.title).navigationBarTitleDisplayMode(.inline)
        .onAppear {guard !loaded else{return};loaded=true;checked=Set(UserDefaults.standard.array(forKey:key) as? [Int] ?? []).intersection(Set(cells.map(\.0))) }
    }
}
