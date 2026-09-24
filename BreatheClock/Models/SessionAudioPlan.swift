import Foundation

/// A small playback score, not a timer: the audio engine queues these real
/// countdown/breath buffers before play, and owns their timing while locked.
struct SessionAudioPlan {
  struct Segment: Hashable {
    enum Content: Hashable {
      case countdown
      case breaths([BreathPhase])
    }
    let content: Content
    var duration: TimeInterval
    var offset: TimeInterval = 0
    var loops = false
  }

  static let introDuration: TimeInterval = 3
  let sessionDuration: TimeInterval?
  private(set) var segments: [Segment] = []

  init(routine: Routine, duration: SessionDuration) {
    sessionDuration = routine.alignedSessionDuration(for: duration)
    segments = (0..<3).map { _ in Segment(content: .countdown, duration: 1) }
    if let stages = routine.program, !stages.isEmpty {
      for stage in stages { append(phases: stage.phases, seconds: stage.duration) }
    } else if let seconds = sessionDuration {
      append(phases: routine.phases, seconds: seconds)
    } else if routine.cycleDuration > 0 {
      segments.append(Segment(content: .breaths(routine.phases), duration: routine.cycleDuration, loops: true))
    }
  }

  /// Resume includes the remaining samples of the interrupted phase. Infinite
  /// playback needs a non-looping suffix before returning to the whole cycle.
  func segments(from elapsed: TimeInterval) -> [Segment] {
    var skip = max(0, elapsed)
    var result: [Segment] = []
    for segment in segments {
      if segment.loops {
        let offset = skip.truncatingRemainder(dividingBy: segment.duration)
        if offset > 0.000_001 {
          result.append(Segment(content: segment.content, duration: segment.duration - offset, offset: offset))
        }
        result.append(segment)
        break
      }
      if skip >= segment.duration {
        skip -= segment.duration
      } else {
        var remainder = segment
        remainder.offset = skip
        remainder.duration -= skip
        result.append(remainder)
        skip = 0
      }
    }
    return result
  }

  private mutating func append(phases: [BreathPhase], seconds: TimeInterval) {
    let cycle = phases.reduce(0) { $0 + $1.seconds }
    guard cycle > 0 else { return }
    var remaining = seconds
    while remaining > 0.000_001 {
      let length = min(cycle, remaining)
      segments.append(Segment(content: .breaths(phases), duration: length))
      remaining -= length
    }
  }
}
