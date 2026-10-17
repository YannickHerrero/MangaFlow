import XCTest
@testable import MangaFlow

@MainActor
final class FavoritesDownloadTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func manga(source: String = "lelscan") -> RemoteManga {
        RemoteManga(id: "/manga/blue-lock?edition=fr", sourceID: source, title: "Blue Lock")
    }
    func testFavoritesPersistExactSourceAndServerWithoutMergingSameTitles() throws {
        let file = directory.appendingPathComponent("favorites.json")
        let favorites = FavoriteStore(file: file)
        try favorites.toggle(manga(), sourceName: "LELScan", serverID: "mac-a")
        try favorites.toggle(manga(source: "other-source"), sourceName: "Other", serverID: "mac-a")
        try favorites.toggle(manga(), sourceName: "LELScan", serverID: "mac-b")
        let restored = FavoriteStore(file: file)
        XCTAssertEqual(restored.items.count, 3)
        let exact = try XCTUnwrap(restored.items.first { $0.serverID == "mac-a" && $0.manga.sourceID == "lelscan" })
        XCTAssertEqual(exact.manga.id, "/manga/blue-lock?edition=fr")
        XCTAssertEqual(exact.sourceName, "LELScan")
        try restored.toggle(manga(), sourceName: "LELScan", serverID: "mac-a")
        XCTAssertFalse(restored.contains(manga(), serverID: "mac-a"))
        XCTAssertTrue(restored.contains(manga(source: "other-source"), serverID: "mac-a"))
        XCTAssertTrue(restored.contains(manga(), serverID: "mac-b"))
        XCTAssertEqual(FavoriteStore(file: file).items.count, 2)
    }
    func testUnreadableFavoriteFileIsNotOverwritten() throws {
        let file = directory.appendingPathComponent("favorites.json")
        let original = Data("incomplete saved data".utf8); try original.write(to: file)
        let favorites = FavoriteStore(file: file)
        XCTAssertNotNil(favorites.loadError)
        XCTAssertThrowsError(try favorites.toggle(manga(), sourceName: "LELScan", serverID: "mac"))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testDownloadErrorsAreVisibleAndButtonCanRetry() async {
        let model = RemoteModel(connection: nil, session: .shared)
        let chapter = RemoteChapter(id: "/chapter/308", title: "308", language: "fr", order: 0)
        await model.download(manga(), chapter: chapter)
        XCTAssertNotNil(model.downloadErrors[ChapterDownloadKey(manga: manga(), chapter: chapter)])
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.requestingDownloads.isEmpty)
    }
    func testQueuedAndFailedStatesMatchExactSourceMangaAndChapter() throws {
        let model = RemoteModel(connection: nil, session: .shared)
        let chapter = RemoteChapter(id: "/chapter/308", title: "308", language: "fr", order: 0)
        model.jobs = [try fixtureJob(state: "running", source: "other-source"), try fixtureJob(state: "failed", source: "lelscan")]
        XCTAssertEqual(model.downloadJob(for: manga(), chapter: chapter)?.state, "failed")
        XCTAssertEqual(model.downloadJob(for: manga(source: "other-source"), chapter: chapter)?.state, "running")
    }
    func testAcceptedDownloadIsShownImmediatelyAndDuplicateTapIsIgnored() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DownloadProtocol.self]
        let session = URLSession(configuration: configuration)
        let model = RemoteModel(connection: ServerConnection(serverURL: URL(string: "https://fixture.example")!, serverID: "mac", deviceID: "phone", token: "fixture-token"), session: session)
        let chapter = RemoteChapter(id: "/chapter/308", title: "308", language: "fr", order: 0)
        DownloadProtocol.status = 202
        DownloadProtocol.response = try JSONEncoder().encode(fixtureJob(state: "queued", source: "lelscan"))
        let task = Task { await model.download(manga(), chapter: chapter) }
        for _ in 0..<100 where model.requestingDownloads.isEmpty { await Task.yield() }
        XCTAssertTrue(model.requestingDownloads.contains(ChapterDownloadKey(manga: manga(), chapter: chapter)))
        await model.download(manga(), chapter: chapter)
        await task.value
        XCTAssertTrue(model.requestingDownloads.isEmpty)
        XCTAssertEqual(model.downloadJob(for: manga(), chapter: chapter)?.state, "queued")
        XCTAssertNil(model.downloadErrors[ChapterDownloadKey(manga: manga(), chapter: chapter)])
        session.invalidateAndCancel()
    }
    func testRejectedServerRequestShowsInlineErrorAndSuccessfulRetryClearsIt() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DownloadProtocol.self]
        let session = URLSession(configuration: configuration)
        let model = RemoteModel(connection: ServerConnection(serverURL: URL(string: "https://fixture.example")!, serverID: "mac", deviceID: "phone", token: "fixture-token"), session: session)
        let chapter = RemoteChapter(id: "/chapter/308", title: "308", language: "fr", order: 0)
        DownloadProtocol.status = 503
        DownloadProtocol.response = Data(#"{"error":{"code":"network_failed","message":"Source unavailable"}}"#.utf8)
        await model.download(manga(), chapter: chapter)
        XCTAssertNotNil(model.downloadErrors[ChapterDownloadKey(manga: manga(), chapter: chapter)])
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.requestingDownloads.isEmpty)
        DownloadProtocol.status = 202
        DownloadProtocol.response = try JSONEncoder().encode(fixtureJob(state: "queued", source: "lelscan"))
        await model.download(manga(), chapter: chapter)
        XCTAssertNil(model.downloadErrors[ChapterDownloadKey(manga: manga(), chapter: chapter)])
        XCTAssertEqual(model.downloadJob(for: manga(), chapter: chapter)?.state, "queued")
        session.invalidateAndCancel()
    }
    private func fixtureJob(state: String, source: String) throws -> RemoteJob {
        let data = Data("""
        {"id":"job-\(source)","kind":"download","target":{"sourceID":"\(source)","manga":{"id":"/manga/blue-lock?edition=fr","sourceID":"\(source)","title":"Blue Lock"},"chapter":{"id":"/chapter/308","title":"308","language":"fr","order":0}},"state":"\(state)","progress":{"completed":0,"total":0}}
        """.utf8)
        return try JSONDecoder().decode(RemoteJob.self, from: data)
    }
}

private final class DownloadProtocol: URLProtocol {
    static var response = Data()
    static var status = 202
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.example" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let data = Self.response
        let status = Self.status
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
