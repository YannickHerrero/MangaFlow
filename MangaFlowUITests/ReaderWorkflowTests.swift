import XCTest

final class ReaderWorkflowTests: XCTestCase {
    func testRealChapterImportReadAndReopen() throws {
        let path = ProcessInfo.processInfo.environment["MANGAFLOW_TEST_CBZ"] ?? ""
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Private chapter fixture is not available on this machine")
        }
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("Chapitre 1196.cbz")
        if FileManager.default.fileExists(atPath: fixture.path) { try FileManager.default.removeItem(at: fixture) }
        try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: fixture)
        let app = XCUIApplication()
        app.launchArguments = ["-import", fixture.path]
        app.launch()
        let closeReader = app.buttons["Fermer la lecture"]
        XCTAssertTrue(closeReader.waitForExistence(timeout: 60), "Conversion should open the reader")
        let scroll = app.scrollViews["readerScroll"]
        XCTAssertTrue(scroll.exists)
        scroll.swipeUp()
        scroll.swipeUp()
        let savedPosition = app.staticTexts["readingPosition"].value as? String
        XCTAssertNotNil(savedPosition, "Reader should expose its current page and panel")
        let reading = XCTAttachment(screenshot: app.screenshot()); reading.name = "Converted chapter"; reading.lifetime = .keepAlways
        add(reading)
        app.buttons["Options de lecture"].tap()
        app.buttons["Voir la page originale"].tap()
        XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5))
        app.buttons["Fermer"].tap()
        closeReader.tap()
        XCTAssertTrue(app.buttons["read-Chapitre 1196"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        let reopen = app.buttons["read-Chapitre 1196"].firstMatch
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        reopen.tap()
        XCTAssertTrue(closeReader.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["readerScroll"].exists)
        XCTAssertEqual(app.staticTexts["readingPosition"].value as? String, savedPosition,
                       "Reopening should restore the current page and panel")
    }
}
