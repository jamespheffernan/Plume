import XCTest
import Combine
@testable import Plume

@MainActor
final class AudioCuePlayerTests: XCTestCase {
  func testPreviewFollowsFourPlayedBuffersThenClears() async {
    let audio = AudioCuePlayer()
    defer { audio.stop() }
    let tones = expectation(description: "Four played tones")
    tones.expectedFulfillmentCount = 4
    let finished = expectation(description: "Preview ended")
    var indices: [Int] = []
    let progress = audio.$previewToneIndex.compactMap { $0 }.sink { index in
      indices.append(index)
      tones.fulfill()
    }
    audio.playBoxPreview(.fork)
    let ending = audio.$previewCue.dropFirst().filter { $0 == nil }.sink { _ in finished.fulfill() }
    defer { progress.cancel(); ending.cancel() }
    await fulfillment(of: [tones, finished], timeout: 20, enforceOrder: true)
    XCTAssertEqual(indices, [0, 1, 2, 3])
    XCTAssertNil(audio.previewCue)
    XCTAssertNil(audio.previewToneIndex)
  }

  func testSwitchingPreviewsCannotRestartTheCancelledOne() async {
    let audio = AudioCuePlayer()
    defer { audio.stop() }
    audio.playBoxPreview(.bowl)
    audio.playBoxPreview(.turf)
    let started = expectation(description: "Latest preview started")
    let progress = audio.$previewToneIndex.compactMap { $0 }.first().sink { _ in started.fulfill() }
    defer { progress.cancel() }
    await fulfillment(of: [started], timeout: 5)
    XCTAssertEqual(audio.previewCue, .turf)
    XCTAssertEqual(audio.previewToneIndex, 0)
    audio.playBoxPreview(.off)
    try? await Task.sleep(for: .seconds(0.3))
    XCTAssertNil(audio.previewToneIndex)
    XCTAssertNil(audio.previewCue)
  }

  func testFiniteSessionCompletesWithoutAViewTimerAndReleasesPlayback() async {
    let audio = AudioCuePlayer()
    defer { audio.stop() }
    let ready = expectation(description: "Playback started")
    let complete = expectation(description: "Breathing completed")
    let routine = Routine(id: "test", category: "Focus", name: "Short", description: "", phases: [
      BreathPhase(kind: .inhale, seconds: 0.5), BreathPhase(kind: .exhale, seconds: 0.5)
    ])
    audio.startSession(cue: .turf, routine: routine, duration: SessionDuration(seconds: 1, label: "1", unit: "s"), from: 3) { success in
      XCTAssertTrue(success)
      ready.fulfill()
    } onComplete: {
      complete.fulfill()
    }
    await fulfillment(of: [ready, complete], timeout: 5, enforceOrder: true)
    let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in audio.sessionPosition == nil }, object: nil)
    await fulfillment(of: [released], timeout: 5)
    XCTAssertNil(audio.playbackError)
  }

  func testStopInvalidatesAQueuedCompletion() async {
    let audio = AudioCuePlayer()
    defer { audio.stop() }
    let ready = expectation(description: "Playback started")
    let complete = expectation(description: "Cancelled completion")
    complete.isInverted = true
    audio.startSession(cue: .bowl, routine: .coherence, duration: SessionDuration.options[0], from: 68.5) { success in
      XCTAssertTrue(success)
      ready.fulfill()
    } onComplete: {
      complete.fulfill()
    }
    await fulfillment(of: [ready], timeout: 5)
    audio.stop()
    await fulfillment(of: [complete], timeout: 1)
    XCTAssertNil(audio.sessionPosition)
  }

  func testAudioOffDoesNotStartAnAudioClock() {
    let audio = AudioCuePlayer()
    var ready = false
    audio.startSession(cue: .off, routine: .coherence, duration: SessionDuration.options[0]) { success in
      ready = success
    } onComplete: { XCTFail("Silent sessions are timed by the foreground UI") }
    XCTAssertTrue(ready)
    XCTAssertNil(audio.sessionPosition)
    XCTAssertNil(audio.previewCue)
  }

  func testTurningSoundOffCancelsPreview() {
    let audio = AudioCuePlayer()
    audio.playBoxPreview(.bowl)
    XCTAssertEqual(audio.previewCue, .bowl)
    audio.playBoxPreview(.off)
    XCTAssertNil(audio.previewCue)
    XCTAssertNil(audio.previewToneIndex)
  }
}
