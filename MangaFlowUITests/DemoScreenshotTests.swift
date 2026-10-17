import XCTest

/// Optional documentation capture, using only the single page selected for the public demonstration.
final class DemoScreenshotTests: XCTestCase {
    func testCapturePublicDemo() throws {
        let archive = "/private/tmp/mangaflow-public-demo.cbz"
        guard FileManager.default.fileExists(atPath: archive) else {
            throw XCTSkip("Run Scripts/capture_demo.sh to prepare the public demonstration")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-import", archive]
        app.launch()
        let hide = app.buttons["Masquer l’interface"]
        XCTAssertTrue(hide.waitForExistence(timeout: 60))
        hide.tap()
        XCTAssertFalse(app.buttons["Fermer la lecture"].exists)
        // Let the system bars finish their disappearance before taking the documentation image.
        Thread.sleep(forTimeInterval: 1)
        capture(app, "demo-reader-start")
        app.scrollViews["readerScroll"].swipeUp()
        capture(app, "demo-reader-scroll")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
