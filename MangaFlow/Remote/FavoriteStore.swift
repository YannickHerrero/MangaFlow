import Foundation
import Observation

struct FavoriteManga: Codable, Identifiable {
    let id: UUID
    let serverID: String
    let sourceName: String
    let manga: RemoteManga
}

@Observable @MainActor
final class FavoriteStore {
    private(set) var items: [FavoriteManga] = []
    private(set) var loadError: String?
    private let file: URL

    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MangaFlowFavorites/favorites.json")
        guard FileManager.default.fileExists(atPath: self.file.path) else { return }
        do { items = try JSONDecoder().decode([FavoriteManga].self, from: Data(contentsOf: self.file)) }
        catch { loadError = "Impossible de charger les favoris : \(error.localizedDescription)" }
    }
    func contains(_ manga: RemoteManga, serverID: String) -> Bool {
        items.contains { $0.serverID == serverID && $0.manga.sourceID == manga.sourceID && $0.manga.id == manga.id }
    }
    func toggle(_ manga: RemoteManga, sourceName: String, serverID: String) throws {
        var updated = items
        if let index = updated.firstIndex(where: { $0.serverID == serverID && $0.manga.sourceID == manga.sourceID && $0.manga.id == manga.id }) {
            updated.remove(at: index)
        } else {
            updated.insert(FavoriteManga(id: UUID(), serverID: serverID, sourceName: sourceName, manga: manga), at: 0)
        }
        try persist(updated)
    }
    func remove(_ favorite: FavoriteManga) throws { try persist(items.filter { $0.id != favorite.id }) }
    private func persist(_ updated: [FavoriteManga]) throws {
        guard loadError == nil else { throw RemoteFailure(code: "favorites_unavailable", message: "Les favoris existants n’ont pas pu être chargés. Ils ont été conservés sur disque.") }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: file, options: .atomic)
        items = updated
    }
}

struct ChapterDownloadKey: Hashable {
    let sourceID: String
    let mangaID: String
    let chapterID: String
    init(manga: RemoteManga, chapter: RemoteChapter) {
        sourceID = manga.sourceID; mangaID = manga.id; chapterID = chapter.id
    }
}
