import SwiftUI
import UniformTypeIdentifiers

/// Keep the original bytes for Files and a lossless UTF-8 view for preview, share and copy.
struct MinisDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    let text: String

    init(data: Data) throws {
        guard let text = String(bytes: data, encoding: .utf8), data.elementsEqual(text.utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.data = data
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        try self.init(data: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
