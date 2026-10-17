import XCTest

final class ThemeWorkflowTests: XCTestCase {
  func testAllThemeAndAppearanceScreensAndPersistence() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    for theme in ["holo", "brutal", "manga"] {
      for appearance in ["light", "dark"] {
        app.launchArguments = ["-theme", theme, "-appearance", appearance]
        app.launch()
        XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 10))
        XCTAssertEqual(
          app.tabBars.count, 0, "The app uses the design tab bars, never a UIKit tab bar")
        capture(app, "\(theme)-\(appearance)-library")
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.textFields["explorerSearch"].waitForExistence(timeout: 5))
        capture(app, "\(theme)-\(appearance)-explorer")
        app.buttons["tab-2"].tap()
        XCTAssertTrue(
          app.staticTexts["Activité"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["ACTIVITÉ / FILE"].exists || app.staticTexts["ACTIVITÉ"].exists)
        capture(app, "\(theme)-\(appearance)-activity")
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.buttons["theme-\(theme)"].waitForExistence(timeout: 5))
        capture(app, "\(theme)-\(appearance)-settings")
        app.buttons["theme-\(theme)"].tap()
        app.buttons["OK"].tap()
        app.terminate()
      }
    }
    app.launchArguments = []
    app.launch()
    app.buttons["Réglages"].tap()
    XCTAssertTrue(app.buttons["theme-manga"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["theme-manga"].value as? String, "Sélectionné")
    app.buttons["theme-holo"].tap()
    XCTAssertEqual(app.buttons["theme-holo"].value as? String, "Sélectionné")
    app.buttons["OK"].tap()
    app.terminate()
    app.launch()
    app.buttons["Réglages"].tap()
    XCTAssertTrue(app.buttons["theme-holo"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["theme-holo"].value as? String, "Sélectionné")
  }
  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
