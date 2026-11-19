import SwiftUI

/// Used in both the editor and snapshot review so they cannot disagree about placement.
struct LayoutPreviewSections: View {
    let recipe: LayoutRecipe
    @ScaledMetric(relativeTo: .caption) private var cellHeight = 40.0
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 5), count: LayoutPlacement.columns)

    var body: some View {
        let plan = LayoutPlacement(recipe)
        Section {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(plan.cells.indices, id: \.self) { i in
                    tile(plan.cells[i])
                        .frame(maxWidth: .infinity).frame(height: cellHeight)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Row \(i / LayoutPlacement.columns + 1), column \(i % LayoutPlacement.columns + 1): \(description(plan.cells[i]))")
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            DisclosureGroup("App positions") {
                ForEach(plan.cells.indices, id: \.self) { i in
                    if case let .app(label) = plan.cells[i] {
                        LabeledContent(label, value: "R\(i / LayoutPlacement.columns + 1) · C\(i % LayoutPlacement.columns + 1)")
                    }
                }
            }
        } header: { Text("Page preview · 4 × 6") } footer: {
            Text("Dashed spaces stay clear for the wallpaper. Grid marks reserve one widget; dots are unused spaces.")
        }
        if !plan.unplaced.isEmpty {
            Section {
                ForEach(plan.unplaced.indices, id: \.self) { Text(plan.unplaced[$0]) }
            } header: { Text("Unplaced (\(plan.unplaced.count))") } footer: {
                Text("These labels do not fit on this page. They stay in your saved plan.")
            }
        }
    }

    @ViewBuilder private func tile(_ cell: LayoutPlacement.Cell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        switch cell {
        case .app(let name):
            shape.fill(Color.accentColor.opacity(0.16))
                .overlay { Text(name).font(.caption.weight(.medium)).lineLimit(2).multilineTextAlignment(.center).padding(2) }
        case .clear: shape.strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        case .widget: shape.fill(.quaternary).overlay { Image(systemName: "square.grid.2x2.fill").foregroundStyle(.secondary) }
        case .empty: Circle().fill(.secondary).frame(width: 4, height: 4)
        }
    }

    private func description(_ cell: LayoutPlacement.Cell) -> String {
        switch cell {
        case .app(let name): return "App, \(name)"
        case .clear: return "Clear for wallpaper"
        case .widget: return "Reserved for widget"
        case .empty: return "Unused"
        }
    }
}
