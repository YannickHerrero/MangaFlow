import XCTest

final class OfflineRemoteReadTests: XCTestCase {
    func testImportedRemoteChapterRemainsReadableWithServerStopped() throws {
        guard FileManager.default.fileExists(atPath: "/private/tmp/mangaflow-test-server-stopped") else {
            throw XCTSkip("Explicit offline check: stop the local server and create the local marker first")
        }
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Sources"].tap()
        XCTAssertTrue(app.staticTexts["Mac injoignable"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Bibliothèque"].tap()
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "read-One Piece")).firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 10))
        local.tap()
        XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["readerScroll"].exists)
    }
}
