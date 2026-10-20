import XCTest

final class OfflineRemoteReadTests: XCTestCase {
    func testImportedRemoteChapterRemainsReadableWithServerStopped() throws {
        guard FileManager.default.fileExists(atPath: "/private/tmp/mangaflow-test-server-stopped") else {
            throw XCTSkip("Explicit offline check: stop the local server and create the local marker first")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        app.buttons["Explorer"].firstMatch.tap()
        app.buttons["openSettings"].tap(); app.buttons["macConnection"].tap()
        XCTAssertTrue(app.staticTexts["Mac injoignable"].waitForExistence(timeout: 10))
        app.buttons["routeBack"].tap(); app.buttons["Fermer les réglages"].tap()
        app.buttons["Bibliothèque"].firstMatch.tap()
        let series = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "series-")).firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "read-")).firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 10))
        local.tap()
        XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["readerScroll"].exists)
    }
}
