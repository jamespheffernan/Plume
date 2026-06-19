import SwiftUI
import UIKit

struct SessionView: View {
  let scheme: BreatheScheme
  let routine: Routine
  let duration: SessionDuration
  let audioCue: AudioCue
  let hapticsEnabled: Bool
  let swellHapticsEnabled: Bool
  let onEnd: () -> Void

  @AppStorage("didSeeBreathPrimer") private var didSeeBreathPrimer = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var startDate = Date()
  @State private var pauseStarted: Date?
  @State private var accumulatedPause: TimeInterval = 0
  @State private var lastIntroDigit: Int?
  @State private var lastBoundaryKey: String?
  @State private var isComplete = false
  @State private var showPrimer = false
  @State private var startedContinuous = false

  private let tick = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
  private let introDuration: TimeInterval = 3

  private var cueStyle: CueStyle {
    routine.outcomeFamily.cueStyle
  }

  private var needsGrounding: Bool {
    routine.outcomeFamily.needsGrounding
  }

  private var isContinuousCue: Bool {
    cueStyle.continuous
  }

  var body: some View {
    Group {
      if showPrimer {
        BreathPrimerView(scheme: scheme, reduceMotion: reduceMotion, onBegin: dismissPrimer)
      } else {
        sessionTimeline
      }
    }
    .onAppear(perform: handleAppear)
    .onDisappear {
      AudioCuePlayer.shared.stopSustained()
      BreathHaptics.shared.stop()
    }
    .onReceive(tick, perform: handleTick)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
  }

  private var sessionTimeline: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
      let elapsed = effectiveElapsed(at: context.date)
      let sessionLimit = sessionDurationLimit
      let cappedElapsed = sessionLimit.map { min(elapsed, $0) } ?? elapsed
      let introRemaining = introCountdownRemaining(at: context.date)
      let state = routine.state(at: cappedElapsed)

      ZStack {
        VStack(spacing: 0) {
          topBar(elapsed: cappedElapsed)
            .padding(.horizontal, 28)
            .padding(.top, 22)

          progressBar(elapsed: cappedElapsed)
            .padding(.horizontal, 28)
            .padding(.top, 14)

          if introRemaining <= 0, let stageTitle = state.stageTitle {
            stageHeader(stageTitle)
              .padding(.top, 18)
          }

          Spacer(minLength: 32)

          if introRemaining > 0 {
            introStage(remaining: introRemaining)
          } else {
            pupilStage(state: state)
          }

          Spacer(minLength: 34)

          controls
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        if isComplete {
          completionOverlay
            .transition(.opacity)
        }
      }
      .background(scheme.paper)
    }
  }

  private var isPaused: Bool {
    pauseStarted != nil
  }

  private func topBar(elapsed: TimeInterval) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(routine.name)
        .font(BreatheFont.display(17, weight: .regular, italic: true))
        .foregroundStyle(scheme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Spacer(minLength: 12)

      Text("\(elapsed.clockText) · \(sessionDurationText)")
        .font(BreatheFont.utility(11, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(2.5)
        .textCase(.uppercase)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
  }

  private func progressBar(elapsed: TimeInterval) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(scheme.track)

        Rectangle()
          .fill(scheme.accent)
          .frame(width: geometry.size.width * sessionProgress(elapsed: elapsed))
      }
    }
    .frame(height: 1)
  }

  /// The orb settles here at full exhale instead of collapsing to a point —
  /// the breath guide should rest, never vanish.
  private let orbRestScale: Double = 0.32

  /// The breathing orb: a quiet vessel ring, a soft halo that swells, and a
  /// gradient sphere with the count nested inside it. At the bottom of an
  /// exhale the sphere dissolves (fillOpacity → 0) into the empty ring while the
  /// numeral crossfades white → ink, so the count stays readable on paper.
  @ViewBuilder
  private func breathOrb(size: CGFloat, scale: Double, halo: Double, fillOpacity: Double, digit: Int) -> some View {
    Circle()
      .stroke(scheme.ink.opacity(0.4), lineWidth: 1)
      .frame(width: size, height: size)

    Circle()
      .fill(scheme.ink)
      .frame(width: size, height: size)
      .scaleEffect(scale * 1.04)
      .blur(radius: 26)
      .opacity(halo * fillOpacity * fillOpacity)

    Circle()
      .fill(
        RadialGradient(
          colors: [scheme.ink.opacity(0.86), scheme.ink],
          center: UnitPoint(x: 0.5, y: 0.42),
          startRadius: 0,
          endRadius: size * 0.6
        )
      )
      .frame(width: size, height: size)
      .scaleEffect(scale)
      .opacity(fillOpacity)

    ZStack {
      Text("\(digit)")
        .foregroundStyle(scheme.ink)
      Text("\(digit)")
        .foregroundStyle(Color.white)
        .opacity(fillOpacity)
    }
    .font(BreatheFont.display(size * 0.52, weight: .ultraLight))
    .monospacedDigit()
    .tracking(-4)
    .scaleEffect(scale)
    .id(digit)
    .transition(.opacity.animation(.easeOut(duration: reduceMotion ? 0 : 0.22)))
  }

  private func introStage(remaining: TimeInterval) -> some View {
    let digit = max(1, Int(ceil(remaining)))
    // Settle down to the inhale's starting size across the countdown, so the
    // first breath flows out of the intro with no jump.
    let remainingFraction = min(max(remaining / introDuration, 0), 1)
    let scale = reduceMotion ? 0.4 : orbRestScale + 0.08 * remainingFraction

    return VStack(spacing: 28) {
      GeometryReader { geometry in
        let size = min(geometry.size.width * 0.78, 288)

        ZStack {
          breathOrb(
            size: size,
            scale: scale,
            halo: reduceMotion ? 0.12 : 0.08 + 0.06 * remainingFraction,
            fillOpacity: 1,
            digit: digit
          )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(height: 304)

      Text("Ready")
        .font(BreatheFont.utility(12, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(5)
        .textCase(.uppercase)
        .frame(height: 16)
    }
    .padding(.horizontal, 24)
  }

  private func pupilStage(state: BreathState) -> some View {
    VStack(spacing: 28) {
      GeometryReader { geometry in
        let size = min(geometry.size.width * 0.78, 288)
        let raw = reduceMotion ? 0.5 : state.pupilScale
        // The orb grows straight from its rest size the instant the breath
        // turns — no frozen dead zone where it fills before it moves.
        let restScale = 0.30
        let scale = reduceMotion ? 0.66 : restScale + (1 - restScale) * raw
        // Fill and grow happen together. Coming out of the empty hold the inhale
        // fills in fast (by ~10% of the breath) while the orb is already
        // swelling; the exhale empties more gently (over ~20%), so the fill-in
        // reads as quicker than the previous fill-out, settling to an empty ring.
        let fillThreshold = state.phase.kind == .inhale ? 0.10 : 0.20
        let fillOpacity = reduceMotion ? 1 : min(1, max(0, raw / fillThreshold))

        ZStack {
          breathOrb(
            size: size,
            scale: scale,
            halo: reduceMotion ? 0.16 : 0.09 + 0.17 * raw,
            fillOpacity: fillOpacity,
            digit: state.countdownDigit
          )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(height: 304)

      Text(state.phase.guidanceLabel)
        .font(BreatheFont.utility(12, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(5)
        .textCase(.uppercase)
        .id(state.phase.guidanceLabel)
        .transition(.opacity.animation(.easeInOut(duration: reduceMotion ? 0 : 0.18)))
        .frame(height: 16)
    }
    .padding(.horizontal, 24)
  }

  private func stageHeader(_ title: String) -> some View {
    VStack(spacing: 5) {
      Text("Stage")
        .font(BreatheFont.utility(9, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(3)
        .textCase(.uppercase)
      Text(title)
        .font(BreatheFont.display(21, weight: .regular, italic: true))
        .foregroundStyle(scheme.ink)
        .id(title)
        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
    }
    .frame(maxWidth: .infinity)
  }

  private var controls: some View {
    HStack(spacing: 12) {
      ghostControl("Restart", action: restart)
      primaryControl(isPaused ? "Resume" : "Pause", action: togglePause)
      ghostControl("End", action: onEnd)
    }
    .padding(.horizontal, 28)
    .disabled(isComplete)
    .opacity(isComplete ? 0.35 : 1)
  }

  /// The filled capsule that anchors the control row — the one action most
  /// likely wanted mid-session, so it reads as the obvious target.
  private func primaryControl(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(BreatheFont.utility(12, weight: .semibold))
        .tracking(2.4)
        .textCase(.uppercase)
        .foregroundStyle(scheme.paper)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Capsule().fill(scheme.ink))
    }
    .buttonStyle(.plain)
  }

  /// Quieter outlined capsules either side of the primary action.
  private func ghostControl(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(BreatheFont.utility(11, weight: .regular))
        .tracking(2.4)
        .textCase(.uppercase)
        .foregroundStyle(scheme.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .overlay(Capsule().stroke(scheme.ink.opacity(0.25), lineWidth: 1))
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var completionOverlay: some View {
    VStack(spacing: 26) {
      Spacer()

      GeometryReader { geometry in
        let size = min(geometry.size.width * 0.78, 288)

        ZStack {
          // The same vessel ring as the breathing orb, now come to rest.
          Circle()
            .stroke(scheme.ink.opacity(0.4), lineWidth: 1)
            .frame(width: size, height: size)

          Circle()
            .fill(scheme.ink)
            .frame(width: size, height: size)
            .scaleEffect(0.62)
            .blur(radius: 26)
            .opacity(0.12)

          Image(systemName: "checkmark")
            .font(.system(size: size * 0.26, weight: .ultraLight))
            .foregroundStyle(scheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(height: 304)

      VStack(spacing: 8) {
        Text("Complete")
          .font(BreatheFont.display(38, weight: .light, italic: true))
          .foregroundStyle(scheme.ink)
        Text(routine.name)
          .font(BreatheFont.utility(12, weight: .regular))
          .foregroundStyle(scheme.muted)
          .tracking(3)
          .textCase(.uppercase)

        if needsGrounding {
          Text("Stay where you are for a moment. Let your breath find its own rhythm before you get up.")
            .font(BreatheFont.utility(13, weight: .light))
            .foregroundStyle(scheme.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 300)
            .padding(.top, 10)
        }
      }

      Spacer()

      HStack(spacing: 12) {
        ghostControl("Restart", action: restart)
        primaryControl("Done", action: onEnd)
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 34)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
  }

  private func sessionProgress(elapsed: TimeInterval) -> Double {
    guard let seconds = sessionDurationLimit, seconds > 0 else {
      return routine.state(at: elapsed).progressInCycle
    }
    return min(max(elapsed / seconds, 0), 1)
  }

  private var sessionDurationLimit: TimeInterval? {
    routine.alignedSessionDuration(for: duration)
  }

  private var sessionDurationText: String {
    sessionDurationLimit.map { $0.clockText } ?? duration.displayText
  }

  private func effectiveElapsed(at date: Date) -> TimeInterval {
    let referenceDate = pauseStarted ?? date
    return max(0, referenceDate.timeIntervalSince(startDate) - accumulatedPause)
  }

  private func introCountdownRemaining(at date: Date) -> TimeInterval {
    let referenceDate = pauseStarted ?? date
    return max(0, startDate.timeIntervalSince(referenceDate) + accumulatedPause)
  }

  private func handleTick(_ date: Date) {
    guard !isPaused, !isComplete, !showPrimer else { return }

    let introRemaining = introCountdownRemaining(at: date)
    if introRemaining > 0 {
      let digit = max(1, Int(ceil(introRemaining)))
      if digit != lastIntroDigit {
        lastIntroDigit = digit
        triggerIntroCue()
      }
      return
    }
    lastIntroDigit = nil

    let elapsed = effectiveElapsed(at: date)
    if let seconds = sessionDurationLimit, elapsed >= seconds {
      completeSession()
      return
    }

    // A continuous cue plays as one seamless looping tone, started once the
    // countdown ends rather than re-triggered at every boundary.
    if isContinuousCue, !startedContinuous {
      startedContinuous = true
      AudioCuePlayer.shared.startContinuous(
        audioCue,
        phases: routine.phases,
        cycleDuration: routine.cycleDuration,
        volumeScale: cueStyle.volumeScale
      )
    }

    let state = routine.state(at: elapsed)
    guard state.boundaryKey != lastBoundaryKey else { return }
    lastBoundaryKey = state.boundaryKey
    triggerBoundaryCue(for: state.phase)
  }

  private func triggerBoundaryCue(for phase: BreathPhase) {
    triggerBoundaryHaptic(for: phase)
    // Continuous cues are a single sustained tone, not per-boundary chimes.
    if !isContinuousCue {
      AudioCuePlayer.shared.play(audioCue, for: phase.kind, phaseDuration: phase.seconds, style: cueStyle)
    }
  }

  private func triggerBoundaryHaptic(for phase: BreathPhase) {
    guard let feel = breathFeel(for: cueStyle) else { return }

    if BreathHaptics.shared.isSupported {
      // Inhale/exhale use the continuous swell; holds use a tick.
      // Each has its own toggle so the swell can be silenced without losing ticks.
      switch phase.kind {
      case .inhale, .exhale:
        guard swellHapticsEnabled else {
          BreathHaptics.shared.stop()
          return
        }
        BreathHaptics.shared.playBreath(phase: phase.kind, duration: phase.seconds, feel: feel)
      case .holdFull, .holdEmpty:
        guard hapticsEnabled else { return }
        BreathHaptics.shared.playBreath(phase: phase.kind, duration: phase.seconds, feel: feel)
      }
    } else if hapticsEnabled, let impact = impactStyle(for: cueStyle) {
      UIImpactFeedbackGenerator(style: impact.style).impactOccurred(intensity: impact.intensity)
    }
  }

  private func breathFeel(for cue: CueStyle) -> BreathHaptics.Feel? {
    switch cue {
    case .soft: return BreathHaptics.Feel(peakIntensity: 0.35, sharpness: 0.1)
    case .coherent: return BreathHaptics.Feel(peakIntensity: 0.3, sharpness: 0.1)
    case .crisp: return BreathHaptics.Feel(peakIntensity: 0.6, sharpness: 0.4)
    case .silent: return nil
    }
  }

  private func impactStyle(
    for cue: CueStyle
  ) -> (style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat)? {
    switch cue {
    case .soft: return (.soft, 0.5)
    case .coherent: return (.soft, 0.4)
    case .crisp: return (.rigid, 0.9)
    case .silent: return nil
    }
  }

  private func triggerIntroCue() {
    AudioCuePlayer.shared.playCountdownTick(audioCue, style: cueStyle)
    if hapticsEnabled {
      let generator = UIImpactFeedbackGenerator(style: .soft)
      generator.impactOccurred(intensity: 0.55)
    }
  }

  private func completeSession() {
    isComplete = true
    BreathHaptics.shared.stop()
    if hapticsEnabled {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    AudioCuePlayer.shared.playCompletion(audioCue)
  }

  private func handleAppear() {
    AudioCuePlayer.shared.prepare(
      cue: audioCue,
      style: cueStyle,
      phases: routine.phases,
      cycleDuration: routine.cycleDuration
    )
    if hapticsEnabled || swellHapticsEnabled { BreathHaptics.shared.prepare() }
    restart()
    showPrimer = !didSeeBreathPrimer
  }

  private func restart() {
    AudioCuePlayer.shared.stopSustained()
    BreathHaptics.shared.stop()
    startedContinuous = false
    startDate = Date().addingTimeInterval(introDuration)
    pauseStarted = nil
    accumulatedPause = 0
    lastIntroDigit = nil
    lastBoundaryKey = nil
    isComplete = false
  }

  private func dismissPrimer() {
    didSeeBreathPrimer = true
    showPrimer = false
    restart()
  }

  private func togglePause() {
    if let pauseStarted {
      accumulatedPause += Date().timeIntervalSince(pauseStarted)
      self.pauseStarted = nil
      AudioCuePlayer.shared.setSustainedPaused(false)
    } else {
      pauseStarted = Date()
      AudioCuePlayer.shared.setSustainedPaused(true)
      BreathHaptics.shared.stop()
    }
  }
}

/// A one-time demo shown before a user's first session: the orb grows on the
/// inhale, rests through the hold, and shrinks on the exhale, with the live
/// label beneath it — so the breathing language is learned before the count.
private struct BreathPrimerView: View {
  let scheme: BreatheScheme
  let reduceMotion: Bool
  let onBegin: () -> Void

  @State private var start = Date()

  private struct Step {
    let label: String
    let seconds: Double
    let from: Double
    let to: Double
  }

  private let steps: [Step] = [
    Step(label: "Breathe in", seconds: 4, from: 0, to: 1),
    Step(label: "Hold", seconds: 2, from: 1, to: 1),
    Step(label: "Breathe out", seconds: 4, from: 1, to: 0),
    Step(label: "Hold", seconds: 2, from: 0, to: 0)
  ]

  private var cycle: Double { steps.reduce(0) { $0 + $1.seconds } }

  private func sample(at elapsed: Double) -> (scale: Double, label: String) {
    let floorScale = 0.30
    guard cycle > 0 else { return (floorScale, steps.first?.label ?? "") }
    let position = elapsed.truncatingRemainder(dividingBy: cycle)
    var cursor = 0.0
    for (index, step) in steps.enumerated() {
      let end = cursor + step.seconds
      if position < end || index == steps.count - 1 {
        let progress = min(max((position - cursor) / step.seconds, 0), 1)
        let eased = 0.5 - 0.5 * cos(Double.pi * progress)
        let value = step.from + (step.to - step.from) * eased
        return (floorScale + (1 - floorScale) * value, step.label)
      }
      cursor = end
    }
    return (floorScale, steps[0].label)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 48)

      Text("How it works")
        .font(BreatheFont.utility(11, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(3)
        .textCase(.uppercase)
        .padding(.bottom, 14)

      Text("Follow the circle.")
        .font(BreatheFont.display(32, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .padding(.bottom, 10)

      Text("It grows as you breathe in, rests while you hold, and shrinks as you breathe out. The number inside counts the seconds.")
        .font(BreatheFont.utility(14, weight: .regular))
        .foregroundStyle(scheme.ink)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 20)

      TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
        let result = sample(at: context.date.timeIntervalSince(start))
        let scale = reduceMotion ? 0.66 : result.scale

        VStack(spacing: 26) {
          GeometryReader { geometry in
            let size = min(geometry.size.width * 0.6, 220)
            ZStack {
              Circle()
                .stroke(scheme.ink.opacity(0.4), lineWidth: 1)
                .frame(width: size, height: size)
              Circle()
                .fill(scheme.ink)
                .frame(width: size, height: size)
                .scaleEffect(scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .frame(height: 236)

          Text(result.label)
            .font(BreatheFont.utility(12, weight: .light))
            .foregroundStyle(scheme.muted)
            .tracking(5)
            .textCase(.uppercase)
            .id(result.label)
            .transition(.opacity.animation(.easeInOut(duration: reduceMotion ? 0 : 0.2)))
            .frame(height: 16)
        }
      }

      Spacer(minLength: 20)

      Button(action: onBegin) {
        Text("Begin")
          .font(BreatheFont.display(18, weight: .regular, italic: true))
          .foregroundStyle(scheme.paper)
          .frame(maxWidth: .infinity)
          .frame(height: 62)
          .background(Capsule().fill(scheme.ink))
      }
      .buttonStyle(.plain)

      Spacer(minLength: 24)
    }
    .padding(.horizontal, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
  }
}
