import XCTest
import SwiftUI
import AVFoundation
@testable import Plume

@MainActor
final class SessionInterruptionTests: XCTestCase {
  override func tearDown() async throws {
    // SwiftUI delivers hosted-view disappearance on its next update. Let that
    // cancellation finish before the next test starts the shared audio player.
    try await Task.sleep(for: .milliseconds(100))
    try await super.tearDown()
  }

  func testDisconnectingHeadphonesStopsTheCompletionTone() async throws {
    try await assertCompletionToneStops(on: Notification(name: AVAudioSession.routeChangeNotification, userInfo: [
      AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
    ]))
  }

  func testAudioInterruptionStopsTheCompletionTone() async throws {
    try await assertCompletionToneStops(on: Notification(name: AVAudioSession.interruptionNotification, userInfo: [
      AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
    ]))
  }

  func testBackgroundRouteNotificationCancelsOnMainThread() async throws {
    try await assertCompletionToneStops(on: Notification(name: AVAudioSession.routeChangeNotification, userInfo: [
      AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
    ]), onBackgroundQueue: true)
  }

  func testBackgroundEngineNotificationCancelsOnMainThread() async throws {
    try await assertCompletionToneStops(on: Notification(name: .AVAudioEngineConfigurationChange), onBackgroundQueue: true)
  }

  func testBackgroundRouteNotificationCancelsPreviewOnMainThread() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let previousWindow = scene.windows.first(where: \.isKeyWindow)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: SettingsView(
      scheme: .sepiaClay, schemeSelection: .constant(.sepiaClay), audioCue: .constant(.bowl),
      hapticsEnabled: .constant(false), swellHapticsEnabled: .constant(false), onBack: {}
    ).environment(\.scenePhase, .active))
    window.makeKeyAndVisible()
    let audio = AudioCuePlayer.shared
    defer {
      audio.stop()
      window.isHidden = true
      window.rootViewController = nil
      previousWindow?.makeKeyAndVisible()
    }
    audio.playBoxPreview(.bowl)
    let started = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in audio.previewToneIndex != nil }, object: nil)
    await fulfillment(of: [started], timeout: 5)
    let publication = audio.objectWillChange.sink {
      XCTAssertTrue(Thread.isMainThread, "Preview cancellation must publish on the main thread")
    }
    defer { publication.cancel() }
    DispatchQueue.global(qos: .userInitiated).async {
      NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [
        AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
      ])
    }
    let stopped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in audio.previewCue == nil }, object: nil)
    await fulfillment(of: [stopped], timeout: 2)
    XCTAssertNil(audio.previewToneIndex)
  }

  private func assertCompletionToneStops(on notification: Notification, onBackgroundQueue: Bool = false) async throws {
    let defaults = UserDefaults.standard
    let previousPrimer = defaults.object(forKey: "didSeeBreathPrimer")
    defaults.set(true, forKey: "didSeeBreathPrimer")
    defer { defaults.set(previousPrimer, forKey: "didSeeBreathPrimer") }

    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    let previousWindow = scene.windows.first(where: \.isKeyWindow)
    let window = UIWindow(windowScene: scene)
    let routine = Routine(id: "test", category: "Focus", name: "Short", description: "", phases: [
      BreathPhase(kind: .inhale, seconds: 0.1), BreathPhase(kind: .exhale, seconds: 0.1)
    ])
    window.rootViewController = UIHostingController(rootView: SessionView(
      scheme: .sepiaClay, routine: routine,
      duration: SessionDuration(seconds: 0.2, label: "Short", unit: nil),
      audioCue: .bowl, hapticsEnabled: false, swellHapticsEnabled: false, onEnd: {}
    ).environment(\.scenePhase, .active))
    window.makeKeyAndVisible()
    let audio = AudioCuePlayer.shared
    defer {
      audio.stop()
      window.isHidden = true
      window.rootViewController = nil
      previousWindow?.makeKeyAndVisible()
    }

    // The actual SessionView has finished its 3s countdown + 0.2s breath.
    // Its Complete screen is now showing while the 5.4s bowl tail still plays.
    let tail = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      (audio.sessionPosition ?? 0) > 3.6
    }, object: nil)
    await fulfillment(of: [tail], timeout: 10)
    XCTAssertNotNil(audio.sessionPosition)
    let publication = audio.objectWillChange.sink {
      XCTAssertTrue(Thread.isMainThread, "Audio cancellation must publish on the main thread")
    }
    defer { publication.cancel() }
    if onBackgroundQueue {
      DispatchQueue.global(qos: .userInitiated).async { NotificationCenter.default.post(notification) }
    } else {
      NotificationCenter.default.post(notification)
    }
    let stopped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in audio.sessionPosition == nil }, object: nil)
    await fulfillment(of: [stopped], timeout: 2)
    XCTAssertNil(audio.sessionPosition, "The Complete screen must still cancel the audible completion tail")
  }
}
