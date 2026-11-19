import SwiftUI
import UniformTypeIdentifiers

/// Export only. Receipt imports never materialize an unbounded FileWrapper.
struct USBRequestDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let bytes: Data
    init(_ job: USBPending) { bytes = job.request }
    init(configuration: ReadConfiguration) throws { throw USBFault.format }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }

    static func readReceipt(at url: URL) throws -> Data {
        guard url.isFileURL else { throw USBFault.format }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var error: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { location in
            result = Result { try readUSBFile(location) }
        }
        if let error { throw error }
        guard let result else { throw USBFault.format }
        return try result.get()
    }
}
