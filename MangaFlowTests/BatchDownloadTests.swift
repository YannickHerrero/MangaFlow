import XCTest
@testable import MangaFlow

@MainActor final class BatchDownloadTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private let manga = RemoteManga(id: "/opaque/manga?x=1", sourceID: "source", title: "Manga")
    private let chapters = (1...3).map { RemoteChapter(id: "https://source/chapter/\($0)", title: "\($0)", language: "fr", order: $0) }
    override func setUp() { suite = UUID().uuidString; defaults = UserDefaults(suiteName: suite)! }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    func testBatchSurvivesRestartAndDoubleTapWithoutDuplicatingTargets() throws {
        let queue = AutomaticImportQueue(defaults: defaults)
        queue.enqueue(serverID: "mac", manga: manga, chapters: chapters)
        queue.enqueue(serverID: "mac", manga: manga, chapters: chapters)
        queue.enqueue(serverID: "mac", manga: RemoteManga(id: manga.id, sourceID: manga.sourceID, title: "Renamed title"), chapters: chapters)
        XCTAssertEqual(queue.batch.count, 3)
        let restored = AutomaticImportQueue(defaults: defaults)
        XCTAssertEqual(restored.batch.map(\.id), queue.batch.map(\.id), "HTTP replay must keep its idempotency keys")
        restored.enqueue(serverID: "other", manga: manga, chapters: chapters)
        restored.pauseBatch(restored.batch[0].id, error: "offline")
        let again = AutomaticImportQueue(defaults: defaults)
        XCTAssertEqual(again.batch.first?.error, "offline")
        again.retryBatch(serverID: "mac", manga: manga)
        XCTAssertNil(again.batch.first?.error)
        again.cancelBatch(serverID: "mac", manga: manga)
        XCTAssertEqual(again.batch.count, 3)
        XCTAssertTrue(again.batch.allSatisfy { $0.serverID == "other" })
    }
    func testBatchFailureRetainsUnsentTargetsAndRetryReusesHTTPKeys() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [BatchProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let connection = ServerConnection(serverURL: URL(string: "https://fixture.invalid")!, serverID: "mac", deviceID: "device", token: "fixture")
        let queue = AutomaticImportQueue(defaults: defaults)
        let model = RemoteModel(connection: connection, session: session, automaticImports: queue); model.connected = true
        model.enqueueDownloads(manga, chapters: chapters)
        let keys = queue.batch.map(\.id)
        BatchProtocol.fail = true; BatchProtocol.keys = []
        await model.submitBatchDownloads()
        XCTAssertEqual(queue.batch.count, 3)
        XCTAssertTrue(queue.batch.allSatisfy { $0.error != nil })
        let restored = AutomaticImportQueue(defaults: defaults)
        restored.retryBatch(serverID: "mac", manga: manga)
        let relaunched = RemoteModel(connection: connection, session: session, automaticImports: restored); relaunched.connected = true
        BatchProtocol.fail = false
        await relaunched.submitBatchDownloads()
        XCTAssertTrue(restored.batch.isEmpty)
        XCTAssertEqual(Array(BatchProtocol.keys.suffix(3)), keys)
        XCTAssertEqual(relaunched.jobs.count, 3)
        XCTAssertTrue(relaunched.jobs.allSatisfy { relaunched.isAwaitingImport($0) })
    }
    func testSourceFavoritesRemainScopedAndLegacyJSONStaysReadable() {
        var raw = SourceFavorites.toggled("[]", server: "a", source: "/id")
        XCTAssertTrue(SourceFavorites.contains(raw, server: "a", source: "/id"))
        XCTAssertFalse(SourceFavorites.contains(raw, server: "b", source: "/id"))
        raw = SourceFavorites.toggled(raw, server: "a", source: "/id")
        XCTAssertEqual(SourceFavorites.keys(raw), [])
    }
    func testLocalChapterCountsExcludeOtherSourcesServersAndRemovedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(store: DocumentStore(root: root))
        func document(server: String, source: String, removed: Bool = false) -> MangaDocument {
            let targetManga = RemoteManga(id: manga.id, sourceID: source, title: manga.title)
            let job = RemoteJob(id: UUID().uuidString, kind: "download", target: .init(sourceID: source, manga: targetManga, chapter: chapters[0]), state: "completed", progress: .init(completed: 1, total: 1), error: nil, artifactID: "artifact", result: nil)
            var doc = MangaDocument(id: UUID(), title: "1", pages: [])
            doc.origin = ChapterOrigin(job: job, serverID: server, sourceName: nil); doc.localRemoved = removed
            return doc
        }
        library.documents = [document(server: "mac", source: "source"), document(server: "other", source: "source"), document(server: "mac", source: "other"), document(server: "mac", source: "source", removed: true)]
        let index = MangaLibraryIndex(library: library, server: "mac", manga: manga)
        XCTAssertEqual(index.documents.count, 1)
        XCTAssertEqual(index.chapterIDs, Set([chapters[0].id]))
    }
}

private final class BatchProtocol: URLProtocol, @unchecked Sendable {
    static var fail = false
    static var keys: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "Idempotency-Key") ?? "missing"
        Self.keys.append(key)
        let status = Self.fail ? 503 : 202
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; body.append(contentsOf: buffer.prefix(count)) }
        }
        let data: Data
        if Self.fail { data = Data(#"{"error":{"code":"network_failed","message":"temporary"}}"#.utf8) }
        else if let target = try? JSONDecoder().decode(RemoteJob.Target.self, from: body) {
            data = (try? JSONEncoder().encode(RemoteJob(id: "job-" + key, kind: "download", target: target, state: "queued", progress: .init(completed: 0, total: 0), error: nil, artifactID: nil, result: nil))) ?? Data()
        } else { data = Data() }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
