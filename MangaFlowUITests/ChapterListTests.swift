import XCTest

final class ChapterListTests: XCTestCase {
    func testLocalChapterSortReadFilterAndPersistence() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/mangaflow-chapter-filter-review.json") else {
            throw XCTSkip("Opt-in chapter filter fixture absent")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        func openSeries() {
            let item = app.buttons["series-chapter-filter-qa"].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 10))
            item.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).tap()
            XCTAssertTrue(app.buttons["openMangaSettings"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.switches["libraryHideReadChapters"].exists)
        }
        openSeries()
        app.buttons["openMangaSettings"].tap()
        let sort = app.descendants(matching: .any)["chapterSortOrder"].firstMatch
        let toggle = app.switches["libraryHideReadChapters"]
        if toggle.value as? String == "1" { toggle.tap() }
        sort.tap(); app.buttons["Décroissant"].firstMatch.tap()
        app.buttons["Fermer les réglages du manga"].tap()
        let older = app.buttons["read-Chapter 312"]
        let newer = app.buttons["read-Chapter 322"]
        XCTAssertTrue(older.exists); XCTAssertTrue(newer.exists)
        XCTAssertLessThan(newer.frame.minY, older.frame.minY)
        app.buttons["openMangaSettings"].tap()
        sort.tap(); app.buttons["Croissant"].firstMatch.tap()
        app.buttons["Fermer les réglages du manga"].tap()
        XCTAssertLessThan(older.frame.minY, newer.frame.minY)
        app.buttons["openMangaSettings"].tap()
        toggle.tap()
        app.buttons["Fermer les réglages du manga"].tap()
        XCTAssertFalse(app.buttons["read-Chapter 321"].exists)
        XCTAssertTrue(older.exists, "Unread gaps stay in the local library")
        XCTAssertTrue(newer.exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Chapter list filters"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch()
        openSeries()
        app.buttons["openMangaSettings"].tap()
        XCTAssertEqual(app.switches["libraryHideReadChapters"].value as? String, "1")
        app.buttons["Fermer les réglages du manga"].tap()
        XCTAssertFalse(app.buttons["read-Chapter 321"].exists)
        XCTAssertLessThan(app.buttons["read-Chapter 312"].frame.minY, app.buttons["read-Chapter 322"].frame.minY)
        app.buttons["openMangaSettings"].tap()
        let sheet = XCTAttachment(screenshot: app.screenshot()); sheet.name = "Manga settings sheet"; sheet.lifetime = .keepAlways; add(sheet)
        app.buttons["editMangaCover"].tap()
        XCTAssertTrue(app.buttons["Utiliser la première page du CBZ"].waitForExistence(timeout: 5))
        app.buttons["Fermer"].tap()
        XCTAssertTrue(app.buttons["openMangaSettings"].waitForExistence(timeout: 5))
    }
}
