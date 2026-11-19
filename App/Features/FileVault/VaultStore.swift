import Darwin
import Foundation

struct VaultFile: Codable, Identifiable, Sendable {
    let id: UUID, name: String, hash: String, size: Int
    var digest: VaultDigest { VaultDigest(hash: hash, size: size) }
}

struct VaultSnapshot: Codable, Identifiable, Sendable {
    let version: Int, id: UUID, date: Date, files: [VaultFile]
    var storedBytes: Int? = nil
    var reusedBytes: Int? = nil
}

struct VaultHistory: Sendable {
    var snapshots: [VaultSnapshot] = []
    var unreadable = 0
}

// Synchronous actor methods deliberately have no suspension points inside a transaction.
actor VaultStore {
    static let shared = VaultStore()
    private let overrideRoot: URL?
    private let fm = FileManager.default
    init(root: URL? = nil) { overrideRoot = root }

    private func directories() throws -> (blobs: URL, snapshots: URL) {
        var root = try overrideRoot ?? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true).appendingPathComponent("FilesVault", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        let blobs = root.appendingPathComponent("blobs", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        for dir in [blobs, snapshots] { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        return (blobs, snapshots)
    }

    private func read(_ url: URL) throws -> VaultSnapshot {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        let cap = 128 * 1024
        guard let data = try input.read(upToCount: cap + 1), data.count <= cap else { throw VaultFault.metadata }
        let s = try JSONDecoder().decode(VaultSnapshot.self, from: data)
        guard s.version == 1, url.lastPathComponent == s.id.uuidString + ".json", (1...32).contains(s.files.count),
              Set(s.files.map(\.id)).count == s.files.count, s.files.allSatisfy({ f in
                  VaultIO.validName(f.name) && (0...VaultIO.fileLimit).contains(f.size) && f.hash.utf8.count == 64
                      && f.hash.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
              }), s.files.reduce(0, { $0 + $1.size }) <= VaultIO.snapshotLimit else { throw VaultFault.metadata }
        return s
    }

    func history() throws -> VaultHistory {
        var h = VaultHistory()
        let urls = try fm.contentsOfDirectory(at: directories().snapshots, includingPropertiesForKeys: nil)
        for url in urls where url.pathExtension == "json" {
            do { h.snapshots.append(try read(url)) } catch { h.unreadable += 1 }
        }
        h.snapshots.sort { $0.date > $1.date }
        return h
    }

    func checkpoint(_ urls: [URL], progress: @Sendable (String) -> Void = { _ in }) throws -> VaultSnapshot {
        guard (1...32).contains(urls.count) else { throw VaultFault.selection }
        let dirs = try directories()
        var files: [VaultFile] = [], added: [URL] = [], total = 0, committed = false
        var stored = 0, reused = 0
        defer { if !committed { for blob in added { try? fm.removeItem(at: blob) } } }
        for (index, url) in urls.enumerated() {
            let ordinal = "\(index + 1) of \(urls.count)"
            progress("Reading file \(ordinal)…")
            let name = url.lastPathComponent
            guard VaultIO.validName(name) else { throw VaultFault.type }
            let digest = try VaultIO.coordinated(url) { src in
                let limit = min(VaultIO.fileLimit, VaultIO.snapshotLimit - total)
                let key = try VaultIO.stream(src, limit: limit)
                let blob = dirs.blobs.appendingPathComponent(key.hash)
                if fm.fileExists(atPath: blob.path) {
                    // A warm hit: re-hash the existing bytes before reuse. No temporary payload write.
                    progress("Verifying stored file \(ordinal)…")
                    try VaultIO.verify(blob, key)
                    reused += key.size
                } else {
                    let temp = dirs.blobs.appendingPathComponent(".stage-" + UUID().uuidString)
                    let handle = try VaultIO.create(temp)
                    defer { try? handle.close(); try? fm.removeItem(at: temp) }
                    let copy = try VaultIO.stream(src, into: handle, limit: limit)
                    guard copy == key else { throw VaultFault.integrity }
                    try handle.synchronize(); try handle.close()
                    progress("Verifying stored file \(ordinal)…")
                    try VaultIO.verify(temp, key)
                    try fm.moveItem(at: temp, to: blob); added.append(blob)
                    stored += key.size
                }
                return key
            }
            files.append(VaultFile(id: UUID(), name: name, hash: digest.hash, size: digest.size))
            total += digest.size
        }
        let snapshot = VaultSnapshot(version: 1, id: UUID(), date: Date(), files: files, storedBytes: stored, reusedBytes: reused)
        progress("Saving checkpoint…")
        try Task.checkCancellation()
        try JSONEncoder().encode(snapshot).write(to: dirs.snapshots.appendingPathComponent(snapshot.id.uuidString + ".json"), options: .atomic)
        committed = true
        return snapshot
    }

    func restore(snapshot: UUID, file: UUID, to folder: URL, progress: @Sendable (String) -> Void = { _ in }) throws {
        let dirs = try directories()
        let record = try read(dirs.snapshots.appendingPathComponent(snapshot.uuidString + ".json"))
        guard let entry = record.files.first(where: { $0.id == file }) else { throw VaultFault.metadata }
        let blob = dirs.blobs.appendingPathComponent(entry.hash)
        progress("Checking saved file…")
        try VaultIO.verify(blob, entry.digest)
        try VaultIO.coordinated(folder, folderWrite: true) { dir in
            let dest = dir.appendingPathComponent(entry.name, isDirectory: false)
            let temp = dir.appendingPathComponent(".assay-" + UUID().uuidString)
            let handle = try VaultIO.create(temp)
            defer { try? handle.close(); try? fm.removeItem(at: temp) }
            progress("Writing restored copy…")
            guard try VaultIO.stream(blob, into: handle, limit: entry.size) == entry.digest else { throw VaultFault.integrity }
            try handle.synchronize()
            try handle.close()
            progress("Checking restored bytes…")
            try VaultIO.verify(temp, entry.digest)
            // Same-directory publication; fail closed on unsupported providers or any collision.
            guard renamex_np(temp.path, dest.path, UInt32(RENAME_EXCL)) == 0 else {
                throw errno == EEXIST ? VaultFault.collision : VaultFault.storage
            }
        }
    }
}
