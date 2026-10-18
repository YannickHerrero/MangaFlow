import XCTest

@testable import MangaFlow

final class SeriesMetadataTests: XCTestCase {
  private func job(
    source: String = "lelscan", mangaID: String = "/naruto", chapterID: String = "/1",
    order: Int = 1
  ) -> RemoteJob {
    RemoteJob(
      id: UUID().uuidString, kind: "download",
      target: .init(
        sourceID: source, manga: RemoteManga(id: mangaID, sourceID: source, title: "Naruto"),
        chapter: RemoteChapter(
          id: chapterID, title: "Chapitre \(order)", language: "fr", order: order)),
      state: "completed", progress: .init(completed: 2, total: 2), error: nil, artifactID: "cbz",
      result: nil)
  }
  func testOpaqueIdentitySeparatesSourcesServersAndAmbiguousDelimiters() {
    let a = ChapterOrigin(job: job(), serverID: "mac", sourceName: "LELScan")!
    let b = ChapterOrigin(job: job(source: "other"), serverID: "mac", sourceName: nil)!
    let c = ChapterOrigin(job: job(), serverID: "other-mac", sourceName: nil)!
    XCTAssertNotEqual(a.seriesID, b.seriesID)
    XCTAssertNotEqual(a.seriesID, c.seriesID)
    XCTAssertNotEqual(ChapterOrigin.key("a:b", "c", "d"), ChapterOrigin.key("a", "b:c", "d"))
    XCTAssertEqual(
      a.seriesID,
      ChapterOrigin(job: job(chapterID: "/2", order: 2), serverID: "mac", sourceName: nil)!.seriesID
    )
  }
  func testOldManifestDecodesWithoutNewFields() throws {
    let doc = MangaDocument(id: UUID(), title: "Old", pages: [])
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(doc)) as? [String: Any])
    for key in ["origin", "manualGroupKey", "manualSeriesID", "lastReadAt", "readComplete"] {
      object.removeValue(forKey: key)
    }
    let restored = try JSONDecoder().decode(
      MangaDocument.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(restored.origin)
    XCTAssertEqual(restored.title, "Old")
    XCTAssertEqual(restored.readingProgress, 0)
  }
  func testReadingProgressAndExplicitUnread() {
    var doc = MangaDocument(
      id: UUID(), title: "Chapter",
      pages: [
        MangaPage(
          id: 0, filename: "page",
          panels: (0..<4).map { ReadingPanel(id: "0-\($0)", rect: .full, confidence: 1) })
      ])
    doc.lastPanelID = "0-2"
    XCTAssertEqual(doc.readingProgress, 0.5)
    doc.readComplete = true
    XCTAssertEqual(doc.readingProgress, 1)
    doc.readComplete = false
    doc.lastPanelID = nil
    XCTAssertEqual(doc.readingProgress, 0)
  }
  func testMetadataTitleMatchingIsExactAfterNormalization() throws {
    let data = Data(
      #"{"id":30011,"title":{"romaji":"NARUTO","english":null,"native":"ナルト"},"synonyms":["Naruto"],"coverImage":{"large":"https://example.com/cover.jpg"}}"#
        .utf8)
    let item = try JSONDecoder().decode(MangaMetadata.self, from: data)
    XCTAssertTrue(item.exactMatch("Naruto"))
    XCTAssertFalse(item.exactMatch("Boruto"))
    XCTAssertFalse(item.exactMatch("Naruto Shippuden"))
    XCTAssertEqual(
      MangaMetadata.normalize("Génie de l’Académie"), MangaMetadata.normalize("Genie de l'Academie")
    )
  }
  @MainActor func testMetadataChoiceAndLocalFallbackPersist() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let metadata = MetadataStore(root: root)
    let item = try JSONDecoder().decode(
      MangaMetadata.self, from: Data(#"{"id":1,"title":{"romaji":"Naruto"}}"#.utf8))
    try metadata.set("series", media: item)
    XCTAssertEqual(MetadataStore(root: root).entries["series"]?.media?.id, 1)
    try metadata.set("series", media: nil)
    XCTAssertNil(MetadataStore(root: root).entries["series"]?.media)
    XCTAssertEqual(MetadataStore(root: root).entries["series"]?.manual, true)
  }
  @MainActor func testMigrationUsesArtifactIdentityRatherThanFilename() throws {
    let library = LibraryModel()
    library.documents = []
    // Do not write to the real library: only a non-matching old import is reconciled.
    var doc = MangaDocument(id: UUID(), title: "Naruto", pages: [])
    doc.remoteArtifactID = "other-mac:cbz"
    library.documents = [doc]
    library.reconcile(jobs: [job()], serverID: "mac", sources: [])
    XCTAssertNil(library.documents[0].origin)
  }
  @MainActor func testSourceChaptersGroupWithoutMergingOtherSourcesAndSortNaturally() {
    let library = LibraryModel()
    library.documents = []
    var a = MangaDocument(id: UUID(), title: "Naruto — 10", pages: [])
    a.origin = ChapterOrigin(job: job(chapterID: "/10", order: 0), serverID: "mac", sourceName: nil)
    var b = MangaDocument(id: UUID(), title: "Naruto — 2", pages: [])
    b.origin = ChapterOrigin(job: job(chapterID: "/2", order: 8), serverID: "mac", sourceName: nil)
    // Model the actual source titles rather than the import filenames.
    a.chapterTitleOverride = "Chapitre 10"
    b.chapterTitleOverride = "Chapitre 2"
    var other = MangaDocument(id: UUID(), title: "Naruto", pages: [])
    other.origin = ChapterOrigin(job: job(source: "other"), serverID: "mac", sourceName: nil)
    library.documents = [a, b, other]
    XCTAssertEqual(library.series.count, 2)
    XCTAssertEqual(
      library.series.first { $0.documents.count == 2 }?.documents.map(\.id), [b.id, a.id])
  }

  @MainActor func testSeriesDisplaysNewestChapterWithoutChangingReadingOrder() throws {
    let library = LibraryModel()
    var older = MangaDocument(id: UUID(), title: "309", pages: [])
    var newer = MangaDocument(id: UUID(), title: "310", pages: [])
    older.origin = ChapterOrigin(job: job(chapterID: "/309", order: 55), serverID: "mac", sourceName: nil)
    newer.origin = ChapterOrigin(job: job(chapterID: "/310", order: 54), serverID: "mac", sourceName: nil)
    older.chapterTitleOverride = "309"
    newer.chapterTitleOverride = "310"
    library.documents = [newer, older]
    let series = try XCTUnwrap(library.series.first)
    XCTAssertEqual(series.chaptersNewestFirst.map(\.displayChapterTitle), ["310", "309"])
    XCTAssertEqual(series.documents.map(\.displayChapterTitle), ["309", "310"])
    older.chapterOrder = 1; newer.chapterOrder = 2
    library.documents = [older, newer]
    XCTAssertEqual(library.series.first?.chaptersNewestFirst.map(\.id), [newer.id, older.id])
    older.chapterTitleOverride = "Bonus ancien"; newer.chapterTitleOverride = "Bonus récent"
    older.chapterOrder = nil; newer.chapterOrder = nil
    library.documents = [older, newer]
    XCTAssertEqual(library.series.first?.chaptersNewestFirst.map(\.id), [newer.id, older.id])
  }

  @MainActor func testArtifactMigrationPersistsOriginAndKeepsReadingPosition() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = DocumentStore(root: root)
    var doc = MangaDocument(id: UUID(), title: "A renamed chapter", pages: [])
    doc.remoteArtifactID = "mac:cbz"
    doc.lastPanelID = "3-2"
    try store.save(doc)
    let library = LibraryModel(store: store)
    library.reconcile(jobs: [job()], serverID: "mac", sources: [])
    let restored = try XCTUnwrap(try store.loadAll().first)
    XCTAssertEqual(restored.origin?.mangaID, "/naruto")
    XCTAssertEqual(restored.lastPanelID, "3-2")
    XCTAssertEqual(restored.title, "A renamed chapter")
  }

  func testServerTimestampsSupportJavaScriptMillisecondsAndLegacySeconds() {
    XCTAssertNotNil(RemoteJob.timestamp("2026-10-18T01:02:03.456Z"))
    XCTAssertNotNil(RemoteJob.timestamp("2026-10-18T01:02:03Z"))
    XCTAssertNil(RemoteJob.timestamp("invalid"))
  }

}
