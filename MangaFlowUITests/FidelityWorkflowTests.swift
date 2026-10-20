import XCTest

final class FidelityWorkflowTests: XCTestCase {
    func testWideGlassTabsFavoriteModesAndSourceHierarchy() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for appearance in ["light", "dark"] {
            app.launchArguments = ["-appearance", appearance]; app.launch()
            XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 10))
            XCTAssertLessThan(app.buttons["tab-0"].frame.minX, 32)
            XCTAssertGreaterThan(app.buttons["tab-1"].frame.maxX, app.windows.firstMatch.frame.maxX - 32)
            capture(app, "\(appearance)-library")
            app.buttons["tab-1"].tap()
            XCTAssertTrue(app.buttons["favoriteKind-mangas"].waitForExistence(timeout: 5))
            app.buttons["favoriteKind-mangas"].tap(); capture(app, "\(appearance)-explorer-mangas")
            app.buttons["favoriteKind-sources"].tap(); capture(app, "\(appearance)-explorer-sources")
            // A live, already paired simulator is optional; no downloads are triggered.
            let source = app.buttons["source-lelscan"]
            if source.waitForExistence(timeout: 5) {
                source.tap()
                XCTAssertFalse(app.buttons["tab-0"].exists, "Source subpages must not retain the root navigation bar")
                _ = app.buttons["manga-/lecture-en-ligne-blue-lock"].waitForExistence(timeout: 10)
                capture(app, "\(appearance)-catalogue")
                app.buttons["Rechercher dans le catalogue"].tap()
                let search = app.textFields["catalogSearch"]
                XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Blue Lock\n")
                let manga = app.buttons["manga-/lecture-en-ligne-blue-lock"]
                if manga.waitForExistence(timeout: 10) {
                    manga.tap()
                    XCTAssertTrue(app.buttons["chapterOptions"].waitForExistence(timeout: 5))
                    _ = app.buttons["downloadRemaining"].waitForExistence(timeout: 15)
                    XCTAssertFalse(app.buttons["tab-0"].exists)
                    XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Blue Lock")).count, 1)
                    capture(app, "\(appearance)-chapitres")
                    app.buttons["chapterOptions"].tap()
                    XCTAssertTrue(app.buttons["Masquer les chapitres lus"].waitForExistence(timeout: 3))
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.75)).tap()
                    app.buttons["routeBack"].tap()
                }
                app.buttons["routeBack"].tap()
                XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 5), "Root tabs must return after popping")
            }
            app.terminate()
        }
    }
    func testSourceFavoritesPersistAcrossRelaunch() throws {
        let app = XCUIApplication(); app.launchArguments = ["-appearance", "light"]; app.launch()
        app.buttons["tab-1"].tap(); app.buttons["favoriteKind-sources"].tap()
        let star = app.buttons["favoriteSource-lelscan"].firstMatch
        guard star.waitForExistence(timeout: 5) else { app.terminate(); throw XCTSkip("Paired simulator source fixture absent") }
        let added = star.label == "Ajouter aux favoris"
        if added { star.tap() }
        capture(app, "source-favoris-apres-ajout")
        let appeared = app.buttons["featured-source-lelscan"].waitForExistence(timeout: 5)
        if !appeared { print(app.debugDescription) }
        XCTAssertTrue(appeared)
        app.terminate(); app.launch(); app.buttons["tab-1"].tap()
        XCTAssertTrue(app.buttons["favoriteKind-sources"].isSelected)
        XCTAssertTrue(app.buttons["featured-source-lelscan"].waitForExistence(timeout: 5))
        capture(app, "source-favoris-persistante")
        if added { app.buttons["favoriteSource-lelscan"].firstMatch.tap() }
        app.terminate()
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
