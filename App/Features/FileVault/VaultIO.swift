import CryptoKit
import Darwin
import Foundation

// Errors crossing the UI boundary must never interpolate a path or provider error.
enum VaultFault: String, Error {
    case selection = "Choose between 1 and 32 individual files."
    case limit = "Selection exceeds 16 MiB per file or 64 MiB per checkpoint."
    case unavailable = "A file or location is unavailable. Check access and try again."
    case type = "Only regular files with a usable file name are supported."
    case integrity = "The bytes did not match the checkpoint. No verified copy was published."
    case collision = "A file with that name already exists. Choose another folder."
    case storage = "Could not finish writing. Check free space and folder permissions."
    case metadata = "Checkpoint information is damaged or unsupported."
}

struct VaultDigest: Equatable {
    let hash: String
    let size: Int
}

enum VaultIO {
    static let fileLimit = 16 * 1024 * 1024
    static let snapshotLimit = 4 * fileLimit

    static func validName(_ s: String) -> Bool {
        !s.isEmpty && s != "." && s != ".." && !s.contains("/") && !s.utf8.contains(0)
            && s.utf8.count <= 255
    }

    // O_EXCL is important even for random temporary names: never truncate an original.
    static func create(_ url: URL) throws -> FileHandle {
        let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw errno == EEXIST ? VaultFault.collision : VaultFault.storage }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    static func stream(_ url: URL, into output: FileHandle? = nil, limit: Int) throws -> VaultDigest {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw VaultFault.unavailable }
        let input = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? input.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw VaultFault.type }
        guard info.st_size <= Int64(limit) else { throw VaultFault.limit }
        var size = 0, sha = SHA256()
        while true {
            try Task.checkCancellation()
            let block = try autoreleasepool { try input.read(upToCount: 64 * 1024) }
            guard let block, !block.isEmpty else { break }
            guard block.count <= limit - size else { throw VaultFault.limit }
            try output?.write(contentsOf: block)
            sha.update(data: block)
            size += block.count
        }
        return VaultDigest(hash: sha.finalize().map { String(format: "%02x", $0) }.joined(), size: size)
    }

    static func verify(_ url: URL, _ expected: VaultDigest) throws {
        do {
            guard try stream(url, limit: expected.size) == expected else { throw VaultFault.integrity }
        } catch VaultFault.limit { throw VaultFault.integrity }
    }

    // Synchronous coordination on the store actor; no scope/bookmark is kept between operations.
    static func coordinated<T>(_ url: URL, folderWrite: Bool = false, _ work: (URL) throws -> T) throws -> T {
        guard url.isFileURL else { throw VaultFault.unavailable }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?, result: Result<T, Error>?
        if folderWrite {
            coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &error) { path in
                result = Result { try work(path) }
            }
        } else {
            coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { path in
                result = Result { try work(path) }
            }
        }
        guard error == nil, let result else { throw VaultFault.unavailable }
        return try result.get()
    }
}
