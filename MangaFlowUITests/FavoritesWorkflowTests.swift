import XCTest

final class FavoritesWorkflowTests: XCTestCase {
  func testBlueLockFavoriteAndVisibleDownloadStatus() throws {
    continueAfterFailure = false
    let pairing = "/private/tmp/mangaflow-online-pairing.json"
    guard FileManager.default.fileExists(atPath: pairing) else {
      throw XCTSkip("Prepare an explicit live pairing before this test")
    }
    let app = XCUIApplication()
    app.launchArguments = ["-pair-file", pairing]
    app.launch()
    let source = app.buttons["source-lelscan"]
    let sourceSearch = app.textFields["explorerSearch"]
    if sourceSearch.waitForExistence(timeout: 30) {
      sourceSearch.tap()
      sourceSearch.typeText("LELScan\n")
    }
    XCTAssertTrue(source.waitForExistence(timeout: 30))
    source.tap()
    app.buttons["Rechercher dans le catalogue"].tap()
    let search = app.textFields["catalogSearch"]
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("Blue Lock\n")
    let manga = app.buttons["manga-/lecture-en-ligne-blue-lock"]
    XCTAssertTrue(manga.waitForExistence(timeout: 20))
    manga.tap()
    let download = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "download-/scan-blue-lock/")
    ).firstMatch
    XCTAssertTrue(download.waitForExistence(timeout: 90))
    let favorite = app.buttons["toggleFavorite"]
    XCTAssertTrue(favorite.exists)
    if favorite.label == "Retirer des favoris" { favorite.tap() }
    favorite.tap()
    XCTAssertEqual(favorite.label, "Retirer des favoris")
    download.tap()
    let disabled = NSPredicate { _, _ in download.exists && !download.isEnabled }
    expectation(for: disabled, evaluatedWith: nil)
    waitForExpectations(timeout: 10)
    let chapterID = String(download.identifier.dropFirst("download-".count))
    let read = app.buttons["readChapter-" + chapterID]
    XCTAssertTrue(
      read.waitForExistence(timeout: 180),
      "The row must show completion and offer import without leaving the manga")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Blue Lock chapter download feedback"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["routeBack"].tap()
    app.buttons["routeBack"].tap()
    app.buttons["Bibliothèque"].firstMatch.tap()
    app.buttons["Explorer"].firstMatch.tap()
    let saved = app.buttons["favorite-lelscan-/lecture-en-ligne-blue-lock"]
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["LELScan"].exists)
    app.terminate()
    app.launchArguments = []
    app.launch()
    app.buttons["Explorer"].firstMatch.tap()
    XCTAssertTrue(saved.waitForExistence(timeout: 10), "Favorite must survive an app restart")
    saved.tap()
    XCTAssertTrue(
      read.waitForExistence(timeout: 30),
      "Favorite must return to the same source and manga, including the completed job")
    read.tap()
    XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 120))
    XCTAssertTrue(app.scrollViews["readerScroll"].exists)
  }
}

extension FavoritesWorkflowTests {
  func testSecondSourceChapterJoinsExistingSeries() throws {
    continueAfterFailure = false
    let pairing = "/private/tmp/mangaflow-online-pairing.json"
    guard FileManager.default.fileExists(atPath: pairing) else {
      throw XCTSkip("Explicit live pairing required")
    }
    let app = XCUIApplication()
    app.launchArguments = ["-appearance", "light", "-pair-file", pairing]
    app.launch()
    let field = app.textFields["explorerSearch"]
    XCTAssertTrue(field.waitForExistence(timeout: 30))
    field.tap()
    field.typeText("LELScan\n")
    app.buttons["source-lelscan"].tap()
    app.buttons["Rechercher dans le catalogue"].tap()
    let catalog = app.textFields["catalogSearch"]
    XCTAssertTrue(catalog.waitForExistence(timeout: 10))
    catalog.tap()
    catalog.typeText("Blue Lock\n")
    let manga = app.buttons["manga-/lecture-en-ligne-blue-lock"]
    XCTAssertTrue(manga.waitForExistence(timeout: 30))
    manga.tap()
    let download = app.buttons["download-/scan-blue-lock/363"]
    XCTAssertTrue(download.waitForExistence(timeout: 90))
    download.tap()
    let read = app.buttons["readChapter-/scan-blue-lock/363"]
    XCTAssertTrue(read.waitForExistence(timeout: 180))
    read.tap()
    XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 120))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Second live chapter imported"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.buttons["Fermer la lecture"].tap()
    let series = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "series-", "Blue Lock")).firstMatch
    XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
    XCTAssertTrue(app.buttons["read-Blue Lock — 363"].waitForExistence(timeout: 10))
  }
}
