import XCTest

final class Plume11UITests: XCTestCase {
  private func launch(route: String = "settings", sound: String = "bowl") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["BC_DIRECT_ROUTE"] = route
    if route == "session" { app.launchEnvironment["BC_DIRECT_SESSION"] = "box" }
    app.launchArguments = ["-didSeeBreathPrimer", "YES", "-didAcknowledgeSafety", "YES", "-audio", sound,
                           "-haptics", "NO", "-hapticsBreathSwell", "NO", "-durationSeconds", "60"]
    app.launch()
    return app
  }

  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<6 {
      if element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  private func wait(_ element: XCUIElement, property: String, equals value: String, timeout: TimeInterval = 8) {
    let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", property, value), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: timeout), .completed)
  }

  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testPreviewProgressAndOffCancellation() {
    let app = launch()
    let bowl = app.buttons["audio-bowl"]
    reveal(bowl, in: app)
    bowl.tap()
    wait(bowl, property: "value", equals: "Playing tone 1 of 4")
    wait(bowl, property: "value", equals: "Playing tone 2 of 4")
    capture("Sound preview", app: app)
    app.buttons["audio-off"].tap()
    wait(bowl, property: "value", equals: "")
    app.terminate()
  }

  func testAboutCreditLocationAndVersion() {
    let app = launch()
    let credit = app.staticTexts["A Turf Terrace product"]
    reveal(credit, in: app)
    XCTAssertTrue(app.staticTexts["Cambridge, UK"].exists)
    XCTAssertTrue(app.staticTexts["1.1.0"].exists)
    capture("About", app: app)
    app.terminate()
  }

  func testSilentSessionPausesInBackgroundAndResumesOnRequest() {
    let app = launch(route: "session", sound: "off")
    let primary = app.buttons["session-primary"]
    wait(primary, property: "label", equals: "Pause")
    XCUIDevice.shared.press(.home)
    Thread.sleep(forTimeInterval: 2)
    app.activate()
    wait(primary, property: "label", equals: "Resume")
    let time = app.staticTexts["session-time"]
    let paused = time.label
    Thread.sleep(forTimeInterval: 2)
    XCTAssertEqual(time.label, paused)
    primary.tap()
    wait(primary, property: "label", equals: "Pause")
    app.terminate()
  }

  func testAudibleSessionKeepsItsClockWhileAnotherAppIsForeground() {
    let app = launch(route: "session", sound: "turf")
    let primary = app.buttons["session-primary"]
    wait(primary, property: "label", equals: "Pause")
    let time = app.staticTexts["session-time"]
    let started = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Elapsed 0:00 of 1:04"), object: time)
    XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 10), .completed)
    let before = time.label
    XCUIDevice.shared.press(.home)
    Thread.sleep(forTimeInterval: 3)
    app.activate()
    wait(primary, property: "label", equals: "Pause")
    XCTAssertNotEqual(time.label, before)
    primary.tap()
    wait(primary, property: "label", equals: "Resume")
    let paused = time.label
    Thread.sleep(forTimeInterval: 2)
    XCTAssertEqual(time.label, paused)
    primary.tap()
    wait(primary, property: "label", equals: "Pause")
    app.terminate()
  }
}
