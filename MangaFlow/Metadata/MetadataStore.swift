import SwiftUI
import CryptoKit

struct MangaMetadata: Codable, Identifiable, Hashable {
    struct Titles: Codable, Hashable { let romaji: String?; let english: String?; let native: String? }
    struct Cover: Codable, Hashable { let large: String? }
    let id: Int
    let title: Titles
    let synonyms: [String]?
    let coverImage: Cover?
    let siteUrl: String?
    var name: String { title.english ?? title.romaji ?? title.native ?? "Manga" }
    func exactMatch(_ value: String) -> Bool {
        ([title.english, title.romaji, title.native].compactMap { $0 } + (synonyms ?? [])).contains { Self.normalize($0) == Self.normalize(value) }
    }
    static func normalize(_ text: String) -> String { text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).filter { $0.isLetter || $0.isNumber } }
}
actor AniListClient {
    private let session: URLSession
    private var nextRequest = Date.distantPast
    init(session: URLSession = .shared) { self.session = session }
    func search(_ title: String) async throws -> [MangaMetadata] {
        let wait = nextRequest.timeIntervalSinceNow
        nextRequest = max(Date(), nextRequest).addingTimeInterval(2.2)
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        var request = URLRequest(url: URL(string: "https://graphql.anilist.co")!)
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": "query($search:String!){Page(page:1,perPage:8){media(search:$search,type:MANGA){id title{romaji english native} synonyms coverImage{large} siteUrl}}}", "variables": ["search": title]])
        let (data, response) = try await session.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 429 {
            let delay = Double((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            nextRequest = Date().addingTimeInterval(max(60, delay))
            throw RemoteFailure(code: "metadata_rate_limit", message: "AniList demande de patienter avant une nouvelle recherche.")
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RemoteFailure(code: "metadata_unavailable", message: "AniList est momentanément indisponible.") }
        struct Envelope: Decodable { struct Result: Decodable { struct Page: Decodable { let media: [MangaMetadata] }; let Page: Page }; let data: Result? }
        guard let result = try JSONDecoder().decode(Envelope.self, from: data).data else { throw RemoteFailure(code: "metadata_failed", message: "AniList n’a pas renvoyé de résultat exploitable.") }
        return result.Page.media
    }
}
@Observable @MainActor
final class MetadataStore {
    struct Entry: Codable { var media: MangaMetadata?; var checkedAt: Date; var manual: Bool }
    private(set) var entries: [String: Entry] = [:]
    private var pending: Set<String> = []
    private let client = AniListClient()
    let root: URL
    private var loadFailed = false
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MangaFlowMetadata")
        let url = self.root.appendingPathComponent("metadata.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do { entries = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: url)) } catch { loadFailed = true }
        }
    }
    func resolve(key: String, title: String) async {
        guard !loadFailed, !pending.contains(key), entries[key] == nil || (entries[key]?.manual == false && Date().timeIntervalSince(entries[key]!.checkedAt) > 30 * 86400) else { return }
        pending.insert(key); defer { pending.remove(key) }
        do {
            let results = try await client.search(title)
            let exact = results.filter { $0.exactMatch(title) }
            try set(key, media: exact.count == 1 ? exact.first : entries[key]?.media, manual: false)
        } catch { /* Covers are optional; keep the last valid result and retry later. */ }
    }
    func search(_ title: String) async throws -> [MangaMetadata] { try await client.search(title) }
    func set(_ key: String, media: MangaMetadata?, manual: Bool = true) throws {
        guard !loadFailed else { throw RemoteFailure(code: "metadata_failed", message: "Les métadonnées existantes sont illisibles et ont été conservées.") }
        var updated = entries; updated[key] = Entry(media: media, checkedAt: Date(), manual: manual)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: root.appendingPathComponent("metadata.json"), options: .atomic)
        entries = updated
    }
    func cover(_ media: MangaMetadata) async -> UIImage? {
        guard let address = media.coverImage?.large, let url = URL(string: address), url.scheme == "https" else { return nil }
        let filename = SHA256.hash(data: Data(address.utf8)).map { String(format: "%02x", $0) }.joined() + ".img"
        let file = root.appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: file.path) { return image }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 10_000_000, let image = UIImage(data: data) else { return nil }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic); return image
        } catch { return nil }
    }
    func clearCoverCache() throws {
        for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "img" { try FileManager.default.removeItem(at: url) }
    }
}
struct SeriesCover: View {
    let key: String
    let title: String
    var fallback: URL? = nil
    @Environment(MetadataStore.self) private var metadata
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else if let fallback { CropImage(url: fallback, rect: .full).frame(maxWidth: .infinity, maxHeight: .infinity) }
                else { ZStack { Color.gray.opacity(0.15); Image(systemName: "book.closed").font(.largeTitle) } }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: metadata.entries[key]?.media?.id) {
            await metadata.resolve(key: key, title: title)
            if let media = metadata.entries[key]?.media { image = await metadata.cover(media) } else { image = nil }
        }
    }
}
struct MetadataPicker: View {
    let key: String
    let title: String
    @Environment(MetadataStore.self) private var metadata
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MangaMetadata] = []
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            List {
                Button("Utiliser la première page du CBZ") { choose(nil) }
                TextField("Titre du manga", text: $query)
                Button("Rechercher sur AniList") { Task { busy = true; defer { busy = false }; do { results = try await metadata.search(query); error = nil } catch { self.error = error.localizedDescription } } }.disabled(busy || query.isEmpty)
                if busy { ProgressView() }
                if let error { Text(error).foregroundStyle(.orange) }
                ForEach(results) { result in
                    Button { choose(result) } label: { HStack { AsyncImage(url: URL(string: result.coverImage?.large ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.1) }.frame(width: 45, height: 65); Text(result.name) } }
                }
            }.navigationTitle("Couverture AniList").toolbar { Button("Fermer") { dismiss() } }.onAppear { query = title }
        }
    }
    private func choose(_ media: MangaMetadata?) { do { try metadata.set(key, media: media); dismiss() } catch { self.error = error.localizedDescription } }
}
