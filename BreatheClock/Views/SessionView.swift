import SwiftUI
import UIKit

struct SessionView: View {
  let scheme: BreatheScheme
  let routine: Routine
  let duration: SessionDuration
  let audioCue: AudioCue
  let hapticsEnabled: Bool
  let onEnd: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var startDate = Date()
  @State private var pauseStarted: Date?
  @State private var accumulatedPause: TimeInterval = 0
  @State private var lastIntroDigit: Int?
  @State private var lastBoundaryKey: String?
  @State private var isComplete = false
  @State private var showGroundingIntro = false
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
      if showGroundingIntro {
        groundingIntroView
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

          if routine.intensity != .gentle {
            Text("Stay seated · stop if you feel faint")
              .font(BreatheFont.utility(9, weight: .light))
              .foregroundStyle(scheme.muted)
              .tracking(2)
              .textCase(.uppercase)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 28)
              .padding(.bottom, 14)
          }

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
  /// gradient sphere with the count nested inside it.
  @ViewBuilder
  private func breathOrb(size: CGFloat, scale: Double, halo: Double, digit: Int) -> some View {
    Circle()
      .stroke(scheme.ink.opacity(0.4), lineWidth: 1)
      .frame(width: size, height: size)

    Circle()
      .fill(scheme.ink)
      .frame(width: size, height: size)
      .scaleEffect(scale * 1.04)
      .blur(radius: 26)
      .opacity(halo)

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

    Text("\(digit)")
      .font(BreatheFont.display(size * 0.52, weight: .ultraLight))
      .foregroundStyle(Color.white)
      .monospacedDigit()
      .tracking(-4)
      .blendMode(.difference)
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
        let scale = orbRestScale + (1 - orbRestScale) * raw

        ZStack {
          breathOrb(
            size: size,
            scale: scale,
            halo: reduceMotion ? 0.16 : 0.09 + 0.17 * raw,
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

  private var groundingIntroView: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 56)

      Text("Before you begin")
        .font(BreatheFont.utility(11, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(3)
        .textCase(.uppercase)
        .padding(.bottom, 18)

      Text("Lie down somewhere you feel safe.")
        .font(BreatheFont.display(30, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .lineSpacing(3)
        .padding(.bottom, 20)

      Text("Connected breathing can surface strong emotion and physical sensation. Let your body be fully supported. There is nothing to push for — you can slow the pace or stop at any time.")
        .font(BreatheFont.utility(14, weight: .regular))
        .foregroundStyle(scheme.ink)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()

      Button(action: beginAfterGrounding) {
        Text("I'm settled — begin")
          .font(BreatheFont.display(18, weight: .regular, italic: true))
          .foregroundStyle(scheme.paper)
          .frame(maxWidth: .infinity)
          .frame(height: 62)
          .background(Capsule().fill(scheme.ink))
      }
      .buttonStyle(.plain)
      .padding(.bottom, 16)

      Button(action: onEnd) {
        Text("Back")
          .font(BreatheFont.utility(11, weight: .medium))
          .foregroundStyle(scheme.muted)
          .tracking(3)
          .textCase(.uppercase)
          .frame(height: 30)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 24)
    }
    .padding(.horizontal, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
  }

  private var controls: some View {
    HStack(spacing: 30) {
      textControl("Restart", action: restart)
      textControl(isPaused ? "Resume" : "Pause", primary: true, action: togglePause)
      textControl("End", action: onEnd)
    }
    .disabled(isComplete)
    .opacity(isComplete ? 0.35 : 1)
  }

  private func textControl(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(BreatheFont.utility(11, weight: primary ? .medium : .regular))
        .foregroundStyle(scheme.ink)
        .tracking(3.1)
        .textCase(.uppercase)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(scheme.ink)
            .frame(height: primary ? 2 : 1)
        }
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

      HStack(spacing: 30) {
        textControl("Restart", action: restart)
        textControl("Done", primary: true, action: onEnd)
      }
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
    guard !isPaused, !isComplete, !showGroundingIntro else { return }

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
    guard hapticsEnabled, let feel = breathFeel(for: cueStyle) else { return }

    // On haptic-capable devices the breath is felt as a swell; otherwise fall
    // back to a single impact tap at the boundary.
    if BreathHaptics.shared.isSupported {
      BreathHaptics.shared.playBreath(phase: phase.kind, duration: phase.seconds, feel: feel)
    } else if let impact = impactStyle(for: cueStyle) {
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
    if hapticsEnabled { BreathHaptics.shared.prepare() }
    restart()
    showGroundingIntro = needsGrounding
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

  private func beginAfterGrounding() {
    showGroundingIntro = false
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
