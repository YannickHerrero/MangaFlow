import Foundation

/// Lightweight chapter records survive local file removal. No page images or detections.
struct ReadingHistoryStore {
    let url: URL
    init(root: URL) { url = root.appendingPathComponent("reading-history.json") }
    func load() throws -> [MangaDocument] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([MangaDocument].self, from: Data(contentsOf: url))
    }
    func save(_ documents: [MangaDocument]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(documents).write(to: url, options: .atomic)
    }
    static func snapshot(_ document: MangaDocument) -> MangaDocument {
        var copy = document
        copy.pages = []
        copy.localRemoved = true
        return copy
    }
}
extension MangaDocument {
    var hasLocalFiles: Bool { localRemoved != true }
    var chapterIdentity: String {
        if let origin { return ChapterOrigin.key(origin.seriesID, origin.chapterID, "") }
        return "local:\(id.uuidString)"
    }
}
extension LibraryModel {
    var allDocuments: [MangaDocument] {
        let ids = Set(documents.map(\.id)), keys = Set(documents.map(\.chapterIdentity))
        return documents + historyDocuments.filter { !ids.contains($0.id) && !keys.contains($0.chapterIdentity) }
    }
    func preserveHistory(_ document: MangaDocument) throws {
        guard !historyFailed else {
            throw RemoteFailure(code: "history_failed", message: "L’historique de lecture est illisible. Les fichiers locaux ont été conservés.")
        }
        var updated = historyDocuments.filter { $0.id != document.id && $0.chapterIdentity != document.chapterIdentity }
        updated.append(ReadingHistoryStore.snapshot(document))
        try ReadingHistoryStore(root: store.root).save(updated)
        historyDocuments = updated
    }
    func removeReadChapters() {
        guard !isBusy else { return }
        error = nil
        for document in documents.filter({ $0.readComplete == true }) {
            remove(document)
            if error != nil { break }
        }
    }
}
