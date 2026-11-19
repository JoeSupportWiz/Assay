import Foundation

@main
struct VaultFixture {
    struct Failed: Error { let check: String }
    static func check(_ value: Bool, _ label: String) throws {
        if !value { throw Failed(check: label) }
    }
    static func reject(_ expected: VaultFault, _ work: () async throws -> Void) async throws {
        do { try await work() } catch let fault as VaultFault where fault == expected { return }
        throw Failed(check: "Expected rejection: \(expected)")
    }

    static func main() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: temp) }
        let root = temp.appendingPathComponent("vault"), out = temp.appendingPathComponent("out")
        try fm.createDirectory(at: out, withIntermediateDirectories: false)
        let store = VaultStore(root: root)
        let a = temp.appendingPathComponent("a.bin"), b = temp.appendingPathComponent("b.bin")
        let old = Data(repeating: 0x37, count: 160_003), changed = Data("changed".utf8)
        try old.write(to: a); try old.write(to: b)
        let first = try await store.checkpoint([a, b])
        let blobs = root.appendingPathComponent("blobs")
        try check(first.files.count == 2 && first.files[0].id != first.files[1].id, "two entries")
        try check(first.files[0].hash == first.files[1].hash, "matching digests")
        try check(try fm.contentsOfDirectory(atPath: blobs.path) == [first.files[0].hash], "one physical blob")
        try check(first.storedBytes == old.count && first.reusedBytes == old.count, "initial duplicate counted once")
        let warm = try await store.checkpoint([a,b]); try check(warm.storedBytes == 0 && warm.reusedBytes == old.count*2, "unchanged checkpoint writes zero payload bytes")
        try changed.write(to: a)
        let next = try await store.checkpoint([a, b])
        try check(next.files[0].hash != first.files[0].hash, "new revision")
        try check(try fm.contentsOfDirectory(atPath: blobs.path).count == 2, "incremental reuse")
        let reopened = VaultStore(root: root)
        try check(try await reopened.history().snapshots.count == 3, "persisted history")
        let file = first.files[0].id
        try await reopened.restore(snapshot: first.id, file: file, to: out)
        try check(try Data(contentsOf: out.appendingPathComponent("a.bin")) == old, "restored previous bytes")
        try await reject(.collision) { try await reopened.restore(snapshot: first.id, file: file, to: temp) }
        try check(try Data(contentsOf: a) == changed, "original untouched")
        let blob = blobs.appendingPathComponent(first.files[0].hash)
        try fm.moveItem(at: blob, to: temp.appendingPathComponent("unavailable"))
        try await reject(.unavailable) { try await reopened.restore(snapshot: first.id, file: first.files[1].id, to: out) }
        try Data(repeating: 0x38, count: old.count).write(to: blob)
        try await reject(.integrity) { try await reopened.restore(snapshot: first.id, file: first.files[1].id, to: out) }
        try check(try fm.contentsOfDirectory(atPath: out.path) == ["a.bin"], "no failed export published")
        let fresh = temp.appendingPathComponent("fresh" )
        try Data([1, 2, 3]).write(to: fresh)
        try await reject(.integrity) { _ = try await reopened.checkpoint([fresh, b]) }
        try check(try await reopened.history().snapshots.count == 3, "failed checkpoint not committed")
        try check(try fm.contentsOfDirectory(atPath: blobs.path).count == 2, "failed transaction rolled back")
        print("PASS: dedup, history, version restore, no overwrite, unavailable/corrupt blob, atomic failure")
    }
}
