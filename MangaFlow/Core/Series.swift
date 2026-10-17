import Foundation

struct ChapterOrigin: Codable, Equatable, Sendable {
    let serverID: String
    let sourceID: String
    let sourceName: String
    let mangaID: String
    let mangaTitle: String
    let chapterID: String
    let chapterTitle: String
    let order: Int
    let language: String?
    init?(job: RemoteJob, serverID: String, sourceName: String?) {
        guard let manga = job.target.manga, let chapter = job.target.chapter else { return nil }
        self.serverID = serverID; sourceID = manga.sourceID; self.sourceName = sourceName ?? manga.sourceID
        mangaID = manga.id; mangaTitle = manga.title; chapterID = chapter.id; chapterTitle = chapter.title
        order = chapter.order; language = chapter.language
    }
    var seriesID: String { Self.key(serverID, sourceID, mangaID) }
    static func key(_ server: String, _ source: String, _ manga: String) -> String {
        // Length-prefixed components: opaque URLs and separators never collide.
        [server, source, manga].map { "\($0.utf8.count):\($0)" }.joined()
    }
}
struct LibrarySeries: Identifiable {
    let id: String
    let title: String
    let documents: [MangaDocument]
    var sourceName: String { documents.compactMap(\.origin).first?.sourceName ?? "Import local" }
    var unread: Int { documents.filter { $0.readComplete != true }.count }
    var lastRead: Date { documents.compactMap(\.lastReadAt).max() ?? .distantPast }
    var added: Date { documents.map(\.created).max() ?? .distantPast }
    var resume: MangaDocument? { documents.filter { $0.readComplete != true }.sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }.first ?? documents.first }
    var progress: Double { documents.isEmpty ? 0 : documents.map(\.readingProgress).reduce(0,+) / Double(documents.count) }
}
extension MangaDocument {
    var seriesID: String { origin?.seriesID ?? manualGroupKey ?? manualSeriesID.map { "manual:\($0)" } ?? "local:\(id)" }
    var displayChapterTitle: String { chapterTitleOverride ?? origin?.chapterTitle ?? title }
    var seriesTitle: String { origin?.mangaTitle ?? manualSeriesTitle ?? title }
    var readingProgress: Double {
        if readComplete == true { return 1 }
        let panels = pages.flatMap(\.panels)
        guard let lastPanelID, let i = panels.firstIndex(where: { $0.id == lastPanelID }) else { return 0 }
        return Double(i) / Double(max(panels.count, 1))
    }
}
extension LibraryModel {
    var series: [LibrarySeries] {
        Dictionary(grouping: documents, by: \.seriesID).map { key, docs in
            LibrarySeries(id: key, title: docs[0].seriesTitle, documents: docs.sorted {
                if $0.chapterOrder != nil || $1.chapterOrder != nil {
                    return ($0.chapterOrder ?? Double($0.origin?.order ?? 0)) < ($1.chapterOrder ?? Double($1.origin?.order ?? 0))
                }
                let a = $0.displayChapterTitle, b = $1.displayChapterTitle
                if a.contains(where: \.isNumber), b.contains(where: \.isNumber), a != b { return DocumentStore.naturalOrder(a,b) }
                return ($0.origin?.order ?? 0) < ($1.origin?.order ?? 0)
            })
        }.sorted { $0.added > $1.added }
    }
    func edit(_ document: MangaDocument, change: (inout MangaDocument) -> Void) {
        var updated = document; change(&updated)
        do { try store.save(updated); update(updated) } catch { self.error = error.localizedDescription }
    }
    func open(_ doc: MangaDocument) {
        if doc.complete && doc.engineVersion == MangaDocument.engine { selected = doc.id } else { resume(doc) }
    }
    func reconcile(jobs: [RemoteJob], serverID: String, sources: [RemoteSource]) {
        for doc in documents where doc.origin == nil {
            guard let artifact = doc.remoteArtifactID,
                  let job = jobs.first(where: { serverID + ":" + ($0.artifactID ?? "") == artifact }),
                  let origin = ChapterOrigin(job: job, serverID: serverID, sourceName: sources.first { $0.id == job.target.sourceID }?.name) else { continue }
            edit(doc) { $0.origin = origin }
        }
    }
}
