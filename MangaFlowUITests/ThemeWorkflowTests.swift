import XCTest

final class ThemeWorkflowTests: XCTestCase {
    override func setUpWithError() throws {
        XCUIApplication().terminate()
        XCUIDevice.shared.orientation = .portrait
    }
    func testUnifiedAppearanceSettingsAndTwoTabNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for appearance in ["light", "dark"] {
            app.launchArguments = ["-appearance", appearance]
            app.launch()
            let ready = app.buttons["Bibliothèque"].firstMatch.waitForExistence(timeout: 10)
            if !ready { print(app.debugDescription); capture(app, "missing-navigation") }
            XCTAssertTrue(ready)
            XCTAssertFalse(app.buttons["tab-2"].exists)
            XCTAssertTrue(app.buttons["Explorer"].firstMatch.exists)
            app.buttons["openSettings"].tap()
            let covers = app.switches["showLibraryCovers"]
            if covers.value as? String == "0" { covers.tap() }
            app.buttons["Fermer les réglages"].tap()
            capture(app, "\(appearance)-library")
            app.buttons["openSettings"].tap()
            XCTAssertTrue(app.buttons["appearance-\(appearance)"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["theme-terminal"].exists)
            XCTAssertTrue(app.switches["showLibraryCovers"].exists)
            capture(app, "\(appearance)-settings")
            app.buttons["appearance-\(appearance == "light" ? "dark" : "light")"].tap()
            app.buttons["Fermer les réglages"].tap()
            app.buttons["Explorer"].firstMatch.tap()
            XCTAssertTrue(app.textFields["explorerSearch"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["Connecter le Mac"].exists)
            XCTAssertFalse(app.buttons["macConnection"].exists)
            XCTAssertFalse(app.buttons["importCBZ"].exists)
            capture(app, "\(appearance)-explorer")
            app.buttons["openSettings"].tap()
            XCTAssertTrue(app.buttons["importCBZ"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["macConnection"].waitForExistence(timeout: 5))
            app.buttons["macConnection"].tap()
            let backReady = app.buttons["routeBack"].waitForExistence(timeout: 5)
            if !backReady { print(app.debugDescription); capture(app, "missing-back") }
            XCTAssertTrue(backReady)
            capture(app, "\(appearance)-connection")
            app.terminate()
        }
    }
    func testAppearanceAndCoversPersistAfterRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        app.buttons["openSettings"].tap()
        XCTAssertTrue(app.buttons["appearance-dark"].waitForExistence(timeout: 5))
        app.buttons["appearance-dark"].tap()
        let covers = app.switches["showLibraryCovers"]
        if covers.value as? String == "1" { covers.tap() }
        app.terminate(); app.launch()
        app.buttons["openSettings"].tap()
        XCTAssertTrue(app.switches["showLibraryCovers"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["showLibraryCovers"].value as? String, "0")
        XCTAssertTrue(app.buttons["appearance-dark"].isSelected)
        app.buttons["appearance-light"].tap()
        capture(app, "light-settings-without-covers")
        app.buttons["Fermer les réglages"].tap()
        capture(app, "light-library-without-covers")
    }
    func testTabBarReservesScrollViewportAcrossRoutes() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        defer { XCUIDevice.shared.orientation = .portrait; app.terminate() }
        XCTAssertTrue(app.buttons["Bibliothèque"].firstMatch.waitForExistence(timeout: 10))
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            for tab in 0..<2 {
                app.buttons[tab == 0 ? "Bibliothèque" : "Explorer"].firstMatch.tap()
                let scroll = app.scrollViews.firstMatch
                XCTAssertTrue(scroll.waitForExistence(timeout: 5))
                scroll.swipeUp()
                XCTAssertTrue(app.buttons["Bibliothèque"].firstMatch.isHittable)
                if tab == 0 {
                    let last = app.buttons["series-redesign-qa-5"]
                    if last.exists {
                        scroll.swipeUp()
                        XCTAssertTrue(last.isHittable)
                        if app.tabBars.count > 0 { XCTAssertLessThanOrEqual(last.frame.maxY, app.tabBars.firstMatch.frame.minY + 1) }
                        last.tap()
                        XCTAssertTrue(app.buttons["routeBack"].waitForExistence(timeout: 5))
                        let detail = app.scrollViews.firstMatch
                        detail.swipeUp()
                        let local = app.buttons["read-Vinland Saga 1"]
                        let chapter = local.exists ? local : app.staticTexts["Lu · supprimé de cet appareil"].firstMatch
                        XCTAssertTrue(chapter.isHittable)
                        if app.tabBars.count > 0 { XCTAssertLessThanOrEqual(chapter.frame.maxY, app.tabBars.firstMatch.frame.minY + 1) }
                        capture(app, "detail-bottom-\(orientation.rawValue)")
                        app.buttons["routeBack"].tap()
                    }
                }
            }
        }
    }
    func testReadCleanupKeepsMangaAndHistoryAfterRelaunch() throws {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/mangaflow-redesign-qa-marker.json")),
              let marker = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              marker["simulator"] == ProcessInfo.processInfo.environment["SIMULATOR_UDID"] else {
            throw XCTSkip("Only run destructive cleanup on the disposable redesign fixture simulator")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch(); app.buttons["openSettings"].tap()
        let delete = app.buttons["deleteReadChapters"]
        for _ in 0..<3 where !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.isEnabled); delete.tap()
        app.buttons["Supprimer de cet appareil"].tap()
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: delete)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 5), .completed)
        app.buttons["Fermer les réglages"].tap()
        app.terminate(); app.launch()
        let manga = app.buttons["series-redesign-qa-0"]
        XCTAssertTrue(manga.waitForExistence(timeout: 10))
        XCTAssertTrue(manga.label.contains("320"))
        manga.tap()
        XCTAssertTrue(app.staticTexts["Lu · supprimé de cet appareil"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["read-Blue Lock 320"].exists)
        XCTAssertTrue(app.buttons["read-Blue Lock 321"].exists)
        capture(app, "local-read-cleanup-history")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
