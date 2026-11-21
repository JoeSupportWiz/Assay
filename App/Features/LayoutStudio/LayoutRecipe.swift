import Foundation

struct LayoutRecipe: Codable, Equatable {
    enum Focus: String, Codable, CaseIterable {
        case top, middle, bottom
        var firstRow: Int {
            switch self { case .top: return 0; case .middle: return 2; case .bottom: return 4 }
        }
    }
    enum Widget: String, Codable, CaseIterable { case none, small, medium }

    var page = ""
    var purpose = ""
    var appLines = ""
    var focus: Focus = .middle
    var widget: Widget = .none
    var sceneID: UUID?

    var title: String { page.trimmingCharacters(in: .whitespacesAndNewlines) }
    var labels: [String] {
        appLines.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct LayoutPlacement: Equatable {
    enum Cell: Equatable { case clear, widget, app(String), empty }
    static let columns = 4, rows = 6
    let cells: [Cell] // Row-major, including all reserved and empty cells.
    let unplaced: [String]

    init(_ recipe: LayoutRecipe) {
        let labels = recipe.labels
        let clearRows = recipe.focus.firstRow..<(recipe.focus.firstRow + 2)
        // First full two-row band outside the subject, anchored on the left.
        let widgetRow = clearRows.contains(0) ? 2 : 0
        let width = recipe.widget == .medium ? Self.columns : (recipe.widget == .small ? 2 : 0)
        var next = 0, result: [Cell] = []
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                if clearRows.contains(row) { result.append(.clear) }
                else if (widgetRow..<(widgetRow + 2)).contains(row), column < width { result.append(.widget) }
                else if next < labels.count { result.append(.app(labels[next])); next += 1 }
                else { result.append(.empty) }
            }
        }
        cells = result
        unplaced = Array(labels.dropFirst(next))
    }
}
