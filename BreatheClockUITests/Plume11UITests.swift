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
    XCTAssertTrue(app.staticTexts["1.1.1"].exists)
    capture("About", app: app)
    app.terminate()
  }

  func testLeaveRatingEntryInAbout() {
    let app = launch()
    let rating = app.buttons["leave-rating"]
    reveal(rating, in: app)
    XCTAssertEqual(rating.label, "Leave a Rating")
    XCTAssertTrue(rating.isEnabled)
    XCTAssertGreaterThanOrEqual(rating.frame.height, 44)
    XCTAssertTrue(app.staticTexts["Cambridge, UK"].exists)
    XCTAssertLessThan(rating.frame.minY, app.staticTexts["A Turf Terrace product"].frame.minY)
    capture("Leave a Rating in About", app: app)
    // Routing is intercepted by SettingsRatingTests; do not open the store here.
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

  func testLargestTextSessionControlsAndCompletionRemainReachable() {
    let app = XCUIApplication()
    app.launchEnvironment["BC_DIRECT_SESSION"] = "box"
    app.launchArguments = ["-didSeeBreathPrimer", "YES", "-didAcknowledgeSafety", "YES",
                           "-audio", "off", "-haptics", "NO", "-hapticsBreathSwell", "NO",
                           "-durationSeconds", "60", "-boxSideSeconds", "4",
                           "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    let primary = app.buttons["session-primary"]
    wait(primary, property: "label", equals: "Pause")
    for button in [primary, app.buttons["Restart"], app.buttons["End"]] {
      XCTAssertTrue(button.isHittable)
      XCTAssertGreaterThan(button.frame.height, 60, "Uncapped AX5 labels need expanded targets")
      XCTAssertGreaterThan(button.frame.width, 300, "AX5 controls should stack")
    }
    primary.tap()
    wait(primary, property: "label", equals: "Resume")
    let time = app.staticTexts["session-time"]
    let paused = time.label
    Thread.sleep(forTimeInterval: 1)
    XCTAssertEqual(time.label, paused)
    capture("AX5 paused controls", app: app)
    primary.tap()
    wait(primary, property: "label", equals: "Pause")
    let complete = app.staticTexts["Complete"]
    XCTAssertTrue(complete.waitForExistence(timeout: 75))
    let sessionDismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: primary)
    XCTAssertEqual(XCTWaiter.wait(for: [sessionDismissed], timeout: 3), .completed,
                   "Completed session controls must leave the accessibility tree after the transition")
    let done = app.buttons["Done"]
    reveal(done, in: app)
    XCTAssertTrue(done.isEnabled)
    capture("AX5 completion actions", app: app)
    done.tap()
    XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 5))
    app.terminate()
  }

  func testFinalBreathCompletesAndRestartReturnsToReady() {
    let app = launch(route: "session", sound: "off")
    let time = app.staticTexts["session-time"]
    let finalSecond = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ==[c] %@", "Elapsed 1:03 of 1:04"), object: time)
    XCTAssertEqual(XCTWaiter.wait(for: [finalSecond], timeout: 72), .completed)
    for frame in 0..<24 { capture("Final breath \(frame)", app: app) }
    XCTAssertTrue(app.staticTexts["Complete"].waitForExistence(timeout: 5))
    capture("Final breath complete", app: app)
    app.buttons["Restart"].tap()
    let ready = app.otherElements["Get ready"].firstMatch
    XCTAssertTrue(ready.waitForExistence(timeout: 2))
    XCTAssertEqual(time.label.lowercased(), "elapsed 0:00 of 1:04")
    capture("Restart Ready", app: app)
    app.buttons["End"].tap()
    XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 5))
    app.terminate()
  }

}
