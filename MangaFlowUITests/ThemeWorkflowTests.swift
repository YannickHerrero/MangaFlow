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
  func testTabBarReservesScrollViewportAcrossThemesAndRoutes() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    defer { XCUIDevice.shared.orientation = .portrait }
    for theme in ["holo", "brutal", "manga"] {
      app.launchArguments = ["-theme", theme, "-appearance", "light"]
      app.launch()
      XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 10))
      for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
        XCUIDevice.shared.orientation = orientation
        for tab in 0..<3 {
          app.buttons["tab-\(tab)"].tap()
          let scroll = app.scrollViews.firstMatch
          XCTAssertTrue(scroll.waitForExistence(timeout: 5))
          scroll.swipeUp()
          scroll.swipeUp()
          assertAboveTabBar(scroll, app: app)
          capture(app, "bottom-\(theme)-\(orientation.rawValue)-tab\(tab)")
        }
      }
      XCUIDevice.shared.orientation = .portrait
      app.buttons["tab-0"].tap()
      let series = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'series-'")).firstMatch
      if series.exists {
        series.tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        scroll.swipeUp(); scroll.swipeUp()
        assertAboveTabBar(scroll, app: app)
        capture(app, "bottom-\(theme)-series-detail")
      }
      app.terminate()
    }
  }
  private func assertAboveTabBar(_ scroll: XCUIElement, app: XCUIApplication) {
    let barTop = (0..<3).map { app.buttons["tab-\($0)"].frame.minY }.min()!
    XCTAssertLessThanOrEqual(scroll.frame.maxY, barTop + 1,
      "The scroll viewport must end above the custom tab bar, including pushed destinations")
  }
  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
