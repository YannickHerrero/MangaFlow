import XCTest

final class OfflineRemoteReadTests: XCTestCase {
    func testImportedRemoteChapterRemainsReadableWithServerStopped() throws {
        guard FileManager.default.fileExists(atPath: "/private/tmp/mangaflow-test-server-stopped") else {
            throw XCTSkip("Explicit offline check: stop the local server and create the local marker first")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.buttons["Mac injoignable"].waitForExistence(timeout: 10))
        app.buttons["tab-0"].tap()
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "read-")).firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 10))
        local.tap()
        XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["readerScroll"].exists)
    }
}
