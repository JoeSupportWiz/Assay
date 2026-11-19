import Foundation

@main enum LayoutStudioTests {
    static func main() throws {
        var recipe = LayoutRecipe()
        recipe.appLines = "  Maps \r\n\n Maps\t\n 読書 📚 \n"
        precondition(recipe.labels == ["Maps", "Maps", "読書 📚"])
        for focus in LayoutRecipe.Focus.allCases {
            recipe.focus = focus
            let clear: Range<Int>
            let widgetStart: Int
            switch focus {
            case .top: clear = 0..<8; widgetStart = 8
            case .middle: clear = 8..<16; widgetStart = 0
            case .bottom: clear = 16..<24; widgetStart = 0
            }
            for size in LayoutRecipe.Widget.allCases {
                recipe.widget = size
                let offsets: [Int]
                switch size {
                case .none: offsets = []
                case .small: offsets = [0, 1, 4, 5]
                case .medium: offsets = Array(0..<8)
                }
                let widget = Set(offsets.map { $0 + widgetStart })
                let capacity = 16 - widget.count
                for count in [0, 1, capacity, capacity + 1, 100] {
                    let input = (0..<count).map { $0 % 3 == 0 ? "Repeated" : "Label \($0)" }
                    recipe.appLines = input.joined(separator: "\n")
                    let result = LayoutPlacement(recipe)
                    precondition(result == LayoutPlacement(recipe) && result.cells.count == 24)
                    var placed = 0
                    for (i, cell) in result.cells.enumerated() {
                        if clear.contains(i) { precondition(cell == .clear && !widget.contains(i)) }
                        else if widget.contains(i) { precondition(cell == .widget) }
                        else if placed < count { precondition(cell == .app(input[placed])); placed += 1 }
                        else { precondition(cell == .empty) }
                    }
                    precondition(placed == min(count, capacity))
                    precondition(result.unplaced == Array(input.dropFirst(placed)))
                }
            }
        }
        try archiveTest(recipe)
        print("Layout Studio passed: 45 grid cases, label handling, snapshot history and corrupt archive protection.")
    }

    static func archiveTest(_ original: LayoutRecipe) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let archive = LayoutArchive(file: dir.appendingPathComponent("plans.json"))
        let initial = try archive.load()
        precondition(initial.isEmpty)
        var recipe = original
        recipe.page = "Weekend"; recipe.purpose = "Reading"; recipe.sceneID = UUID()
        let first = LayoutSnapshot(recipe: recipe, sceneNameAtSave: "Library")
        _ = try archive.save(first)
        recipe.appLines = "Books"; recipe.sceneID = nil
        let second = LayoutSnapshot(recipe: recipe, sceneNameAtSave: nil)
        _ = try archive.save(second)
        let reloaded = try LayoutArchive(file: archive.file).load()
        precondition(reloaded == [second, first])
        precondition(LayoutPlacement(reloaded[1].recipe) == LayoutPlacement(original))
        let invalid = Data("not a layout".utf8)
        try invalid.write(to: archive.file)
        do { _ = try archive.save(second); preconditionFailure("Overwrote corrupt data") } catch is DecodingError { }
        let untouched = try Data(contentsOf: archive.file)
        precondition(untouched == invalid)
    }
}
