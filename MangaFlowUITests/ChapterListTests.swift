import XCTest

final class ChapterListTests: XCTestCase {
    func testLocalChapterSortReadFilterAndPersistence() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/mangaflow-chapter-filter-review.json") else {
            throw XCTSkip("Opt-in chapter filter fixture absent")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-theme", "terminal"]; app.launch()
        func openSeries() {
            let item = app.buttons["series-chapter-filter-qa"].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 10))
            item.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).tap()
            XCTAssertTrue(app.descendants(matching: .any)["chapterSortOrder"].firstMatch.waitForExistence(timeout: 5))
        }
        openSeries()
        let sort = app.descendants(matching: .any)["chapterSortOrder"].firstMatch
        let toggle = app.switches["libraryHideReadChapters"]
        if toggle.value as? String == "1" { toggle.tap() }
        sort.tap(); app.buttons["Décroissant"].firstMatch.tap()
        let older = app.buttons["read-Chapter 312"]
        let newer = app.buttons["read-Chapter 322"]
        XCTAssertTrue(older.exists); XCTAssertTrue(newer.exists)
        XCTAssertLessThan(newer.frame.minY, older.frame.minY)
        sort.tap(); app.buttons["Croissant"].firstMatch.tap()
        XCTAssertLessThan(older.frame.minY, newer.frame.minY)
        toggle.tap()
        XCTAssertFalse(app.buttons["read-Chapter 321"].exists)
        XCTAssertTrue(older.exists, "Unread gaps stay in the local library")
        XCTAssertTrue(newer.exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Chapter list filters"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch()
        openSeries()
        XCTAssertEqual(app.switches["libraryHideReadChapters"].value as? String, "1")
        XCTAssertFalse(app.buttons["read-Chapter 321"].exists)
        XCTAssertLessThan(app.buttons["read-Chapter 312"].frame.minY, app.buttons["read-Chapter 322"].frame.minY)
    }
}
