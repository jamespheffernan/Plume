import CoreHaptics
import Foundation

/// Plays the breath as a felt swell: a continuous haptic whose intensity rises
/// through the inhale and releases through the exhale, mirroring the orb. Holds
/// get a single soft tick to mark the transition, then stillness.
///
/// Requires haptic hardware (iPhone 8 and later). On the simulator and
/// unsupported devices `isSupported` is false and the caller falls back to a
/// simple impact tap.
final class BreathHaptics {
  static let shared = BreathHaptics()

  /// One place to tune the feel. Intensity/sharpness are 0...1 (CoreHaptics).
  struct Feel {
    let peakIntensity: Float
    let sharpness: Float
  }

  let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  private var engine: CHHapticEngine?
  private var activePlayer: CHHapticPatternPlayer?

  private init() {}

  func prepare() {
    guard isSupported, engine == nil else { return }
    engine = try? CHHapticEngine()
    engine?.isAutoShutdownEnabled = true
    engine?.resetHandler = { [weak self] in
      try? self?.engine?.start()
    }
    try? engine?.start()
  }

  /// Drive a single phase. Inhale swells up, exhale releases down, holds tick once.
  func playBreath(phase: BreathPhase.Kind, duration: TimeInterval, feel: Feel) {
    guard isSupported, let engine, duration > 0 else { return }
    stop()

    let pattern: CHHapticPattern?
    switch phase {
    case .inhale:
      pattern = try? swellPattern(duration: duration, feel: feel, rising: true)
    case .exhale:
      pattern = try? swellPattern(duration: duration, feel: feel, rising: false)
    case .holdFull, .holdEmpty:
      pattern = try? tickPattern(feel: feel)
    }

    guard let pattern else { return }
    do {
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
      activePlayer = player
    } catch {
      activePlayer = nil
    }
  }

  func stop() {
    try? activePlayer?.stop(atTime: CHHapticTimeImmediate)
    activePlayer = nil
  }

  func stopEngine() {
    stop()
    engine?.stop()
  }

  // MARK: - Patterns

  /// A continuous event whose intensity follows the same raised-cosine ease as
  /// the breathing orb, so the swell and the visual rise are in lockstep.
  private func swellPattern(duration: TimeInterval, feel: Feel, rising: Bool) throws -> CHHapticPattern {
    let samples = 6
    let points: [CHHapticParameterCurve.ControlPoint] = (0...samples).map { step in
      let progress = Double(step) / Double(samples)
      let eased = 0.5 - 0.5 * cos(Double.pi * progress)
      let value = rising ? eased : (1 - eased)
      return CHHapticParameterCurve.ControlPoint(
        relativeTime: duration * progress,
        value: Float(value)
      )
    }

    let curve = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: points,
      relativeTime: 0
    )

    let event = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: feel.peakIntensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: feel.sharpness)
      ],
      relativeTime: 0,
      duration: duration
    )

    return try CHHapticPattern(events: [event], parameterCurves: [curve])
  }

  private func tickPattern(feel: Feel) throws -> CHHapticPattern {
    let event = CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: feel.peakIntensity * 0.55),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: feel.sharpness)
      ],
      relativeTime: 0
    )
    return try CHHapticPattern(events: [event], parameters: [])
  }
}
