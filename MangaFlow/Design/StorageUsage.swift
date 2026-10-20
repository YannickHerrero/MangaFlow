import Foundation

struct StorageUsage: Sendable {
    var chapters: Int64 = 0
    var covers: Int64 = 0
    var cache: Int64 = 0
    var total: Int64 { chapters + covers + cache }
    static var cacheRoot: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MangaFlow") }
    static func measure(library: URL, metadata: URL) -> Self {
        Self(chapters: bytes(library), covers: bytes(metadata), cache: bytes(cacheRoot))
    }
    static func bytes(_ root: URL) -> Int64 {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
        var total: Int64 = 0
        while let file = files?.nextObject() as? URL {
            if let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
        }
        return total
    }
    static func formatted(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
