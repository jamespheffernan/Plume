import XCTest
@testable import Plume

final class SessionAudioPlanTests: XCTestCase {
  func testGuidedStagesCutTheirLastCycleAtTheStageBoundary() {
    let routine = Routine(id: "test", category: "Calm", name: "Stages", description: "", phases: [], program: [
      ProgramStage(title: "First", phases: [BreathPhase(kind: .inhale, seconds: 4), BreathPhase(kind: .exhale, seconds: 6)], duration: 15),
      ProgramStage(title: "Second", phases: [BreathPhase(kind: .inhale, seconds: 3), BreathPhase(kind: .exhale, seconds: 3)], duration: 12)
    ])
    let plan = SessionAudioPlan(routine: routine, duration: SessionDuration.options[0])
    XCTAssertEqual(plan.sessionDuration, 27)
    XCTAssertEqual(plan.segments.dropFirst(3).map(\.duration), [10, 5, 6, 6])
  }

  func testResumeSkipsElapsedAudioInsteadOfRestartingTheBreath() {
    let plan = SessionAudioPlan(routine: Routine.byID("box")!, duration: SessionDuration.options[0])
    let remaining = plan.segments(from: 9)
    XCTAssertEqual(remaining.count, 4)
    XCTAssertEqual(remaining[0].offset, 6)
    XCTAssertEqual(remaining[0].duration, 10)
    XCTAssertEqual(remaining.reduce(0) { $0 + $1.duration }, 58)
    XCTAssertTrue(plan.segments(from: 67).isEmpty)
  }

  func testResumeInAnInfiniteCyclePlaysItsRemainderThenLoops() {
    let infinite = SessionDuration.options.last!
    let plan = SessionAudioPlan(routine: .coherence, duration: infinite)
    XCTAssertNil(plan.sessionDuration)
    let remaining = plan.segments(from: 30)
    XCTAssertEqual(remaining.count, 2)
    XCTAssertEqual(remaining[0].offset, 5)
    XCTAssertEqual(remaining[0].duration, 6)
    XCTAssertFalse(remaining[0].loops)
    XCTAssertEqual(remaining[1].duration, 11)
    XCTAssertTrue(remaining[1].loops)
  }

  func testEveryRoutineQueuesItsFullAlignedDuration() {
    for routine in Routine.all {
      for duration in routine.durationOptions {
        let plan = SessionAudioPlan(routine: routine, duration: duration)
        if let seconds = routine.alignedSessionDuration(for: duration) {
          XCTAssertEqual(plan.segments.reduce(0) { $0 + $1.duration }, 3 + seconds, accuracy: 0.000_001, routine.id)
          XCTAssertFalse(plan.segments.contains(where: \.loops), routine.id)
        } else {
          XCTAssertTrue(plan.segments.last?.loops == true, routine.id)
          XCTAssertEqual(plan.segments.last?.duration, routine.cycleDuration, routine.id)
        }
      }
    }
  }

  func testBackgroundModeDeclaresActualAudioPlayback() {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], ["audio"])
  }

  func testResumeDuringCountdownKeepsOnlyTheUnplayedTicks() {
    let plan = SessionAudioPlan(routine: .coherence, duration: SessionDuration.options[0])
    let remaining = plan.segments(from: 1.25)
    XCTAssertEqual(remaining[0].content, .countdown)
    XCTAssertEqual(remaining[0].offset, 0.25)
    XCTAssertEqual(remaining[0].duration, 0.75)
    XCTAssertEqual(remaining[1].content, .countdown)
    XCTAssertEqual(remaining[1].duration, 1)
  }

  func testBoxSessionQueuesCountdownAndWholeBreaths() {
    let routine = Routine.byID("box")!
    let plan = SessionAudioPlan(routine: routine, duration: SessionDuration.options[0])
    XCTAssertEqual(plan.sessionDuration, 64)
    XCTAssertEqual(plan.segments.count, 7)
    XCTAssertEqual(plan.segments.prefix(3).map(\.duration), [1, 1, 1])
    XCTAssertEqual(plan.segments.dropFirst(3).map(\.duration), [16, 16, 16, 16])
    XCTAssertEqual(plan.segments.reduce(0) { $0 + $1.duration }, 67)
    XCTAssertFalse(plan.segments.contains(where: \.loops))
  }
}
