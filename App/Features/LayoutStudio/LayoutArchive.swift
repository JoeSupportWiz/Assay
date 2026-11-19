import Foundation

struct LayoutSnapshot: Identifiable, Codable, Equatable {
    var id = UUID()
    var savedAt = Date()
    let recipe: LayoutRecipe
    let sceneNameAtSave: String?
}

/// Accessed synchronously by the planner on the main actor. Never replace an unreadable archive.
struct LayoutArchive {
    let file: URL

    static func local() throws -> Self {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        return Self(file: support.appendingPathComponent("LayoutStudio/plans-v1.json"))
    }

    func load() throws -> [LayoutSnapshot] {
        do { return try JSONDecoder().decode([LayoutSnapshot].self, from: Data(contentsOf: file)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
    }

    func save(_ snapshot: LayoutSnapshot) throws -> [LayoutSnapshot] {
        var history = try load()
        history.insert(snapshot, at: 0)
        let data = try JSONEncoder().encode(history)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return history
    }
}
