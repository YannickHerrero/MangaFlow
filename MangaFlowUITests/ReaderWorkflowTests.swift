import XCTest

final class ReaderWorkflowTests: XCTestCase {
    func testPageTapZoomsIndividualCaseInlineAndSecondTapRestoresPage() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/mangaflow-panel-zoom-review.json") else {
            throw XCTSkip("Explicit inline zoom fixture absent")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-theme", "holo"]; app.launch()
        let series = app.buttons["series-panel-zoom-qa"].firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
        app.buttons["read-Panel Zoom QA"].tap()
        let toggle = app.descendants(matching: .any)["readerOriginalPages"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if !app.buttons["original-page-0"].exists { toggle.tap() }
        let page = app.buttons["original-page-0"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        let scroll = app.scrollViews["readerScroll"]
        let saved = scroll.value as? String
        let frame = page.frame
        let point = page.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.30))
        point.tap()
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Case agrandie"), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 3), .completed, "Tap state: \(String(describing: page.value))")
        XCTAssertFalse(app.buttons["Fermer"].exists, "Page mode must not open the original sheet")
        XCTAssertEqual(page.frame.minY, frame.minY, accuracy: 1)
        XCTAssertEqual(page.frame.width, frame.width, accuracy: 1)
        XCTAssertEqual(page.frame.height, frame.height, accuracy: 1)
        XCTAssertEqual(scroll.value as? String, saved)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Individual panel inline zoom"; attachment.lifetime = .keepAlways; add(attachment)
        point.doubleTap()
        XCTAssertFalse(app.buttons["Fermer la lecture"].exists)
        XCTAssertEqual(page.value as? String, "Case agrandie", "Double tap must not toggle zoom")
        point.doubleTap()
        XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 5))
        point.tap()
        let restoredPage = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Page entière"), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredPage], timeout: 3), .completed)
        XCTAssertEqual(scroll.value as? String, saved)
        XCTAssertEqual(page.frame.minY, frame.minY, accuracy: 1)
        XCTAssertEqual(page.frame.width, frame.width, accuracy: 1)
        XCTAssertEqual(page.frame.height, frame.height, accuracy: 1)
        for (position, expected) in [(CGVector(dx: 0.75, dy: 0.13), "Bulle agrandie"),
                                     (CGVector(dx: 0.18, dy: 0.60), "Texte agrandi")] {
            let textPoint = page.coordinate(withNormalizedOffset: position)
            textPoint.tap()
            let enlarged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: page)
            XCTAssertEqual(XCTWaiter.wait(for: [enlarged], timeout: 3), .completed)
            XCTAssertFalse(app.buttons["Fermer"].exists)
            XCTAssertEqual(scroll.value as? String, saved)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = expected; capture.lifetime = .keepAlways; add(capture)
            textPoint.tap()
            let reset = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Page entière"), object: page)
            XCTAssertEqual(XCTWaiter.wait(for: [reset], timeout: 3), .completed)
        }
        toggle.tap()
        let cropped = app.buttons["panel-0-0"]
        XCTAssertTrue(cropped.waitForExistence(timeout: 5))
        cropped.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.30)).tap()
        XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5), "Panel-mode tap keeps its original zoom sheet")
        app.buttons["Fermer"].tap()
    }

    func testNextChapterStartsAtBeginningEvenWhenPreviouslyFinished() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/mangaflow-reader-next-review.json") else {
            throw XCTSkip("Explicit next-chapter review fixture absent")
        }
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["-theme", "holo"]; app.launch()
        let series = app.buttons["series-reader-qa"].firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
        let read = app.buttons["read-Reader QA 1"].firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 10)); read.tap()
        XCTAssertTrue(app.buttons["Fermer la lecture"].waitForExistence(timeout: 10))
        if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'original-page-'")).firstMatch.exists {
            app.descendants(matching: .any)["readerOriginalPages"].firstMatch.tap()
        }
        let next = app.buttons["nextChapter"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); next.tap()
        XCTAssertTrue(app.navigationBars["Reader QA 2"].waitForExistence(timeout: 10))
        let scroll = app.scrollViews["readerScroll"]
        XCTAssertEqual(scroll.value as? String, "Page 1, case 1")
        XCTAssertTrue(app.buttons["panel-0-0"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Next chapter starts at page one"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testOriginalPagesToggleKeepsCurrentPageAndPersists() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/mangaflow-reader-review"),
              FileManager.default.fileExists(atPath: "/tmp/mangaflow-reader-next-review.json") else {
            throw XCTSkip("Explicit reader review requires an already imported private chapter")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "holo"]
        app.launch()
        let series = app.buttons["series-reader-qa"].firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10)); series.tap()
        let read = app.buttons["read-Reader QA 2"].firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        let readID = read.identifier
        read.tap()
        XCTAssertTrue(app.descendants(matching: .any)["readerOriginalPages"].firstMatch.waitForExistence(timeout: 60))
        app.buttons["Options de lecture"].tap()
        app.buttons["Revenir au début"].tap()
        if !app.buttons["original-page-0"].exists { app.descendants(matching: .any)["readerOriginalPages"].firstMatch.tap() }
        XCTAssertTrue(app.buttons["original-page-0"].waitForExistence(timeout: 5))
        let scroll = app.scrollViews["readerScroll"]
        let first = app.buttons["original-page-0"], second = app.buttons["original-page-1"]
        XCTAssertEqual(first.frame.maxY, second.frame.minY, accuracy: 1)
        first.tap()
        XCTAssertFalse(app.buttons["Fermer"].exists, "Original page taps no longer open a sheet")
        scroll.swipeUp(); scroll.swipeUp()
        let page = (scroll.value as? String ?? "").components(separatedBy: ",")[0]
        XCTAssertFalse(page.isEmpty)
        app.descendants(matching: .any)["readerOriginalPages"].firstMatch.tap()
        XCTAssertTrue(NSPredicate(format: "value BEGINSWITH %@", page).evaluate(with: scroll))
        app.descendants(matching: .any)["readerOriginalPages"].firstMatch.tap()
        app.buttons["Fermer la lecture"].tap()
        XCTAssertTrue(app.buttons[readID].firstMatch.waitForExistence(timeout: 5))
        app.buttons[readID].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["readerOriginalPages"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(NSPredicate(format: "value BEGINSWITH %@", page).evaluate(with: app.scrollViews["readerScroll"]))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Original pages continuous reading"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.descendants(matching: .any)["readerOriginalPages"].firstMatch.tap()
    }

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
        XCTAssertFalse(app.staticTexts["readingPosition"].exists, "Reader must not show a bottom page counter")
        let cover = app.buttons["panel-0-full"]
        let nextPanel = app.buttons["panel-1-0"]
        XCTAssertTrue(cover.exists); XCTAssertTrue(nextPanel.exists)
        XCTAssertEqual(cover.frame.maxY, nextPanel.frame.minY, accuracy: 1,
                       "Panels must touch, including across page boundaries")
        app.buttons["Masquer l’interface"].tap()
        XCTAssertFalse(closeReader.exists, "Immersive reading hides the top controls")
        cover.tap()
        XCTAssertTrue(app.buttons["Fermer"].waitForExistence(timeout: 5), "Single tap must still open the original while controls are hidden")
        app.buttons["Fermer"].tap()
        cover.doubleTap()
        XCTAssertTrue(closeReader.waitForExistence(timeout: 5), "Double tap must restore the controls")
        XCTAssertFalse(app.buttons["Fermer"].exists, "Double tap must not also open the page")
        scroll.swipeUp()
        scroll.swipeUp()
        let savedPosition = scroll.value as? String
        XCTAssertNotNil(savedPosition, "Reader should expose its current page and panel")
        let reading = XCTAttachment(screenshot: app.screenshot()); reading.name = "Converted chapter"; reading.lifetime = .keepAlways
        add(reading)
        app.buttons["Masquer l’interface"].tap()
        let immersive = XCTAttachment(screenshot: app.screenshot()); immersive.name = "Immersive reading"; immersive.lifetime = .keepAlways
        add(immersive)
        scroll.doubleTap()
        XCTAssertTrue(closeReader.waitForExistence(timeout: 5))
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
        XCTAssertEqual(app.scrollViews["readerScroll"].value as? String, savedPosition,
                       "Reopening should restore the current page and panel")
    }
}
