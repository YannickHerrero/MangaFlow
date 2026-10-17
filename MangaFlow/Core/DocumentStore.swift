import Foundation
import ZIPFoundation

struct DocumentStore: Sendable {
    let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MangaFlow", isDirectory: true)
    }
    func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func pageURL(_ doc: MangaDocument, _ page: MangaPage) -> URL { folder(doc.id).appendingPathComponent(page.filename) }
    func save(_ document: MangaDocument) throws {
        try FileManager.default.createDirectory(at: folder(document.id), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(document).write(to: folder(document.id).appendingPathComponent("manifest.json"), options: .atomic)
    }
    func loadAll() throws -> [MangaDocument] {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .compactMap { try? JSONDecoder().decode(MangaDocument.self, from: Data(contentsOf: $0.appendingPathComponent("manifest.json"))) }
            .sorted { $0.created > $1.created }
    }
    func remove(_ document: MangaDocument) throws { try FileManager.default.removeItem(at: folder(document.id)) }

    static func supportedPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !path.contains("\\"), !parts.contains(".."),
              !parts.contains(where: { $0.hasPrefix(".") || $0 == "__MACOSX" }) else { return false }
        return ["jpg", "jpeg", "png"].contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
    static func naturalOrder(_ lhs: String, _ rhs: String) -> Bool {
        let comparison = lhs.compare(rhs, options: [.numeric, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return comparison == .orderedSame ? lhs < rhs : comparison == .orderedAscending
    }

    func importArchive(_ source: URL) throws -> MangaDocument {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 1_500_000_000 else { throw MangaError.invalidArchive("Ce prototype accepte les CBZ jusqu’à 1,5 Go.") }
        let archive: Archive
        do { archive = try Archive(url: source, accessMode: .read) }
        catch { throw MangaError.invalidArchive("Impossible d’ouvrir ce CBZ. Vérifie qu’il s’agit d’un ZIP non chiffré.") }
        let entries = archive.filter { $0.type == .file && Self.supportedPath($0.path) }
            .sorted { Self.naturalOrder($0.path, $1.path) }
        guard !entries.isEmpty else { throw MangaError.invalidArchive("Ce CBZ ne contient aucune page JPEG ou PNG exploitable.") }
        guard entries.count <= 3000 else { throw MangaError.invalidArchive("Ce prototype est limité à 3 000 pages par fichier.") }
        var total: UInt64 = 0
        for entry in entries {
            guard entry.uncompressedSize < 100_000_000 else { throw MangaError.invalidArchive("Une image dépasse la limite de 100 Mo.") }
            total += UInt64(entry.uncompressedSize)
        }
        guard total <= 3_000_000_000 else { throw MangaError.invalidArchive("Les images décompressées dépassent la limite de 3 Go.") }
        let free = (try? root.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
        guard free > Int64(total) + 100_000_000 else { throw MangaError.invalidArchive("L’espace libre est insuffisant pour importer ce CBZ.") }
        var doc = MangaDocument(id: UUID(), title: source.deletingPathExtension().lastPathComponent, pages: [])
        let dir = folder(doc.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            for (index, entry) in entries.enumerated() {
                try Task.checkCancellation()
                let name = String(format: "page-%05d.%@", index, URL(fileURLWithPath: entry.path).pathExtension.lowercased())
                let destination = dir.appendingPathComponent(name)
                _ = try archive.extract(entry, to: destination)
                doc.pages.append(MangaPage(id: index, filename: name))
            }
            try save(doc)
            return doc
        } catch {
            try? FileManager.default.removeItem(at: dir)
            throw error
        }
    }
}
