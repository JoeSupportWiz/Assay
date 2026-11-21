import Foundation

/// Only the latest local state exists. No file URLs, bookmarks, device IDs or history.
enum USBJob: Codable, Equatable {
    case idle, pending(USBPending), received(USBReceipt)
}

func readUSBFile(_ url: URL) throws -> Data {
    guard url.isFileURL else { throw USBFault.format }
    let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard info.isRegularFile == true, info.isSymbolicLink != true else { throw USBFault.format }
    let limit = USBReceipt.byteLimit
    if let size = info.fileSize, size > limit { throw USBFault.size }
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    var data = Data()
    while let part = try file.read(upToCount: limit + 1 - data.count), !part.isEmpty {
        data.append(part)
        guard data.count <= limit else { throw USBFault.size }
    }
    return data
}

/// Serialize the compare-and-commit across all entry views. Never overwrite a
/// different job just because a picker or confirmation dialog was already open.
@MainActor struct USBJobStore {
    let file: URL
    static func local() throws -> Self {
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var dir = support.appendingPathComponent("USBHandoff", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try dir.setResourceValues(values)
        #endif
        return Self(file: dir.appendingPathComponent("job.json"))
    }

    func load() throws -> USBJob {
        do { return try JSONDecoder().decode(USBJob.self, from: readUSBFile(file)) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain &&
            [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) { return .idle }
    }

    private func commit(_ next: USBJob, replacing expected: USBJob) throws -> USBJob {
        guard try load() == expected else { throw USBFault.changed }
        if next == .idle { try FileManager.default.removeItem(at: file) }
        else {
            let bytes = try JSONEncoder().encode(next)
            #if os(iOS)
            try bytes.write(to: file, options: [.atomic, .completeFileProtection])
            #else
            try bytes.write(to: file, options: .atomic)
            #endif
        }
        return next
    }

    func create(replacing expected: USBJob, now: Date = Date()) throws -> USBJob {
        if case .pending = expected { throw USBFault.changed }
        return try commit(.pending(USBPending(id: UUID(), created: now)), replacing: expected)
    }

    func abandon(_ job: USBPending) throws -> USBJob { try commit(.idle, replacing: .pending(job)) }

    func accept(_ data: Data, for job: USBPending, now: Date = Date()) throws -> USBJob {
        let receipt = try USBReceipt.validate(data, for: job, now: now)
        return try commit(.received(receipt), replacing: .pending(job))
    }
}
