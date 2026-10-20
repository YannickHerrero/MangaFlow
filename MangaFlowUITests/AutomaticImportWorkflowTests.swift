import XCTest

final class AutomaticImportWorkflowTests: XCTestCase {
  func testSingleDownloadTapImportsWithoutOpeningReader() throws {
    continueAfterFailure = false
    let pairing = "/private/tmp/mangaflow-online-pairing.json"
    guard FileManager.default.fileExists(atPath: pairing) else {
      throw XCTSkip("Explicit live pairing required")
    }
    let app = XCUIApplication()
    app.launchArguments = ["-appearance", "light", "-pair-file", pairing]
    app.launch()
    let search = app.textFields["explorerSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 30))
    search.tap()
    search.typeText("LELScan\n")
    app.buttons["source-lelscan"].tap()
    app.buttons["Rechercher dans le catalogue"].tap()
    let catalog = app.textFields["catalogSearch"]
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    catalog.tap()
    catalog.typeText("Blue Lock\n")
    let manga = app.buttons["manga-/lecture-en-ligne-blue-lock"]
    XCTAssertTrue(manga.waitForExistence(timeout: 30))
    manga.tap()
    let download = app.buttons["download-/scan-blue-lock/362"]
    XCTAssertTrue(download.waitForExistence(timeout: 90))
    download.tap()
    // No import action: completion of the one download action must produce local readability.
    let read = app.buttons["readChapter-/scan-blue-lock/362"]
    XCTAssertTrue(read.waitForExistence(timeout: 240))
    XCTAssertEqual(read.label, "Lire")
    XCTAssertFalse(
      app.buttons["Fermer la lecture"].exists, "An automatic import must not interrupt browsing")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "One tap chapter imported"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
    app.launchArguments = []
    app.launch()
    app.buttons["Explorer"].firstMatch.tap()
    let favorite = app.buttons["favorite-lelscan-/lecture-en-ligne-blue-lock"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 15))
    favorite.tap()
    XCTAssertTrue(read.waitForExistence(timeout: 60))
    read.tap()
    XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 15))
  }
}
