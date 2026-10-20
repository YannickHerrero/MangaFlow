import XCTest
@testable import MangaFlow

final class ChapterListFilterTests: XCTestCase {
    private let manga = RemoteManga(id: "/blue-lock", sourceID: "lelscan", title: "Blue Lock")
    private func chapter(_ n: String, order: Int = 0) -> RemoteChapter {
        .init(id: "/opaque/\(n)?lang=fr", title: "Blue Lock \(n)", language: "fr", order: order)
    }
    private func document(_ n: String, read: Bool = true, server: String = "mac", source: String = "lelscan", mangaID: String = "/blue-lock") -> MangaDocument {
        let chapter = chapter(n)
        let job = RemoteJob(id: "job", kind: "download", target: .init(sourceID: source, manga: .init(id: mangaID, sourceID: source, title: manga.title), chapter: chapter), state: "completed", progress: .init(completed: 0, total: 0), error: nil, artifactID: nil, result: nil)
        var doc = MangaDocument(id: UUID(), title: "Renamed import", pages: [])
        doc.origin = ChapterOrigin(job: job, serverID: server, sourceName: nil)
        doc.readComplete = read
        return doc
    }
    func testBoundaryIsInclusiveAndHidesUnreadGapsBelowHighestCompletedChapter() {
        let chapters = [chapter("322", order: 0), chapter("321", order: 1), chapter("320.5", order: 2), chapter("312", order: 3)]
        let docs = [document("321"), document("312", read: false), document("999", read: false)]
        let boundary = ChapterListFilter.readBoundary(documents: docs, serverID: "mac", manga: manga, chapters: chapters)
        XCTAssertEqual(boundary, Decimal(321))
        XCTAssertEqual(ChapterListFilter.remote(chapters, boundary: boundary, mangaTitle: manga.title).map(\.title), ["Blue Lock 322", "Blue Lock 321"])
        XCTAssertEqual(ChapterListFilter.remote(chapters, boundary: nil, mangaTitle: manga.title).count, 4)
    }
    func testIdentityAndCompletedStatusAreRequired() {
        let docs = [document("900", server: "other"), document("800", source: "other"), document("700", mangaID: "/other"), document("600", read: false)]
        XCTAssertNil(ChapterListFilter.readBoundary(documents: docs, serverID: "mac", manga: manga, chapters: []))
        XCTAssertNil(ChapterListFilter.readBoundary(documents: [document("321")], serverID: nil, manga: manga, chapters: []))
    }
    func testNumericParsingDoesNotUseMangaNumbersVolumesOrConnectorIndices() {
        XCTAssertEqual(ChapterListFilter.number(in: "7 Seeds — Chapitre 321,5 : Suite", mangaTitle: "7 Seeds"), Decimal(string: "321.5"))
        XCTAssertEqual(ChapterListFilter.number(in: "Vol. 12 Ch. 321.5", mangaTitle: "Blue Lock"), Decimal(string: "321.5"))
        XCTAssertEqual(ChapterListFilter.number(in: "Blue Lock 321 VF", mangaTitle: "Blue Lock"), 321)
        XCTAssertNil(ChapterListFilter.number(in: "Bonus été 2026", mangaTitle: "Blue Lock"))
        XCTAssertNil(ChapterListFilter.number(in: "Couverture", mangaTitle: "Blue Lock"))
        let special = RemoteChapter(id: "bonus", title: "Bonus été 2026", language: nil, order: -999)
        XCTAssertEqual(ChapterListFilter.remote([special], boundary: 321, mangaTitle: manga.title), [special])
    }
    func testOriginalIdentitySurvivesLocalRenameAndCatalogRefresh() {
        var doc = document("321")
        doc.chapterTitleOverride = "Chapitre 999"
        doc.chapterOrder = 999
        XCTAssertEqual(ChapterListFilter.readBoundary(documents: [doc], serverID: "mac", manga: manga, chapters: []), 321)
        let refreshed = RemoteChapter(id: doc.origin!.chapterID, title: "Chapter 321.5", language: nil, order: 900)
        XCTAssertEqual(ChapterListFilter.readBoundary(documents: [doc], serverID: "mac", manga: manga, chapters: [refreshed]), Decimal(string: "321.5"))
        let renamed = RemoteChapter(id: doc.origin!.chapterID, title: "Finale", language: nil, order: 0)
        XCTAssertEqual(ChapterListFilter.readBoundary(documents: [doc], serverID: "mac", manga: manga, chapters: [renamed]), 321)
    }
    func testLocalFilterOnlyHidesActuallyReadChaptersAndNeverMutatesReadingOrder() {
        var older = document("312", read: false); older.chapterOrder = 312
        var read = document("321"); read.chapterOrder = 321
        var newer = document("322", read: false); newer.chapterOrder = 322
        let series = LibrarySeries(id: "series", title: "Blue Lock", documents: [older, read, newer])
        XCTAssertEqual(ChapterListFilter.local(series, ascending: false, hideRead: false).map(\.id), [newer.id, read.id, older.id])
        XCTAssertEqual(ChapterListFilter.local(series, ascending: true, hideRead: true).map(\.id), [older.id, newer.id])
        XCTAssertEqual(series.documents.map(\.id), [older.id, read.id, newer.id])
        let allRead = LibrarySeries(id: "series", title: "Blue Lock", documents: [read])
        XCTAssertTrue(ChapterListFilter.local(allRead, ascending: false, hideRead: true).isEmpty)
    }
}
