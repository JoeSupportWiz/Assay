import SwiftUI
import UniformTypeIdentifiers

/// Export only. All imports go through the capped streaming reader instead of FileWrapper.
struct SceneJSONFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { throw CocoaError(.fileReadUnsupportedScheme) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }

    static func read(_ url: URL) throws -> ScenePacket {
        guard url.isFileURL else { throw ScenePacket.Fault.format }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<ScenePacket, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { file in
            result = Result {
                let info = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true else { throw ScenePacket.Fault.format }
                let limit = ScenePacket.byteLimit
                if let size = info.fileSize, size > limit { throw ScenePacket.Fault.size }
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                var data = Data()
                while let part = try handle.read(upToCount: min(8192, limit + 1 - data.count)), !part.isEmpty {
                    data.append(part)
                    guard data.count <= limit else { throw ScenePacket.Fault.size }
                }
                return try ScenePacket.decode(data)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ScenePacket.Fault.format }
        return try result.get()
    }
}
