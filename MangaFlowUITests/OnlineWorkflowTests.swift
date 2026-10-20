import XCTest

/// Explicit live test. The short-lived secret file is prepared locally, never committed.
final class OnlineWorkflowTests: XCTestCase {
    func testPairDownloadImportAndReadOffline() throws {
        let pairing = "/private/tmp/mangaflow-online-pairing.json"
        guard FileManager.default.fileExists(atPath: pairing) else { throw XCTSkip("Prepare live pairing with Server/scripts/prepare-live-test.mjs") }
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Local network permission") { alert in
            for title in ["Allow", "Autoriser", "OK"] where alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            return false
        }
        app.launchArguments = ["-pair-file", pairing]
        app.launch()
        let source = app.buttons["source-lelscan"]
        XCTAssertTrue(source.waitForExistence(timeout: 30), "Real pairing should expose sources")
        source.tap()
        app.buttons["sourceOptions"].tap()
        app.buttons["syncCatalog"].tap()
        app.buttons["Rechercher dans le catalogue"].tap()
        let search = app.textFields["catalogSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("One Piece\n")
        let manga = app.buttons["manga-/lecture-en-ligne-one-piece"]
        XCTAssertTrue(manga.waitForExistence(timeout: 120), "The live connector must synchronize its catalog")
        manga.tap()
        let download = app.buttons["download-/scan-one-piece/1196"]
        XCTAssertTrue(download.waitForExistence(timeout: 120), "Live chapter list")
        download.tap()
        // The Mac keeps downloading while the app is closed. On relaunch the
        // persisted automatic import brings the chapter into the library.
        app.terminate()
        app.launchArguments = []
        app.launch()
        let series = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "One Piece")).firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 180))
        series.tap()
        let local = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "read-One Piece")).firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 120))
        local.tap()
        let close = app.buttons["Fermer la lecture"]
        XCTAssertTrue(close.waitForExistence(timeout: 120), "Transfer, validation and existing conversion must complete before opening reader")
        XCTAssertTrue(app.scrollViews["readerScroll"].exists)
        close.tap()
        app.terminate()
        // A subsequent launch never requires the online tab to open a local document.
        app.launch()
        XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
        XCTAssertTrue(local.waitForExistence(timeout: 10))
        local.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10))
    }
}
