import SwiftUI
import UIKit

/// BOLT / Control Pause measurement: a silent, distraction-free stopwatch that
/// times the comfortable post-exhale hold (the first urge to breathe), not the
/// maximum breath-hold. Used to track CO2 tolerance over time.
struct AssessmentView: View {
  let scheme: BreatheScheme
  let routine: Routine
  let onBack: () -> Void

  @AppStorage("lastBoltScore") private var lastBoltScore = 0
  @AppStorage("lastBoltAt") private var lastBoltAt = 0.0

  @State private var stage: Stage = .intro
  @State private var startDate = Date()
  @State private var measured = 0

  private enum Stage: Equatable {
    case intro
    case holding
    case result
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
        .padding(.horizontal, 24)
        .padding(.top, 24)

      switch stage {
      case .intro:
        introContent
      case .holding:
        holdingContent
      case .result:
        resultContent
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
    .animation(.easeInOut(duration: 0.35), value: stage)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
  }

  private var topBar: some View {
    HStack {
      Button(action: onBack) {
        HStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 12, weight: .semibold))
          Text("Back")
            .font(BreatheFont.utility(12, weight: .regular))
            .tracking(2.1)
        }
        .textCase(.uppercase)
        .foregroundStyle(scheme.muted)
        .frame(height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Spacer()
    }
  }

  // MARK: - Intro

  private var introContent: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 24)

      Text(routine.name)
        .font(BreatheFont.display(52, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .tracking(-1)
        .padding(.bottom, 18)

      VStack(alignment: .leading, spacing: 16) {
        step("1", "Breathe normally for a moment, then let out a relaxed exhale.")
        step("2", "Pinch your nose and start the timer.")
        step("3", "Stop at the first definite urge to breathe — never your maximum hold.")
      }
      .frame(maxWidth: 300)
      .padding(.horizontal, 24)

      if lastBoltScore > 0 {
        Text("Last score · \(lastBoltScore)s")
          .font(BreatheFont.utility(11, weight: .medium))
          .foregroundStyle(scheme.muted)
          .tracking(2.4)
          .textCase(.uppercase)
          .padding(.top, 28)
      }

      Spacer()

      if let note = routine.safetyNote {
        Text(note)
          .font(BreatheFont.utility(11, weight: .light))
          .foregroundStyle(scheme.muted)
          .multilineTextAlignment(.center)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 300)
          .padding(.bottom, 20)
      }

      primaryButton("Start hold", action: startHold)
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
  }

  private func step(_ number: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number)
        .font(BreatheFont.display(20, weight: .light, italic: true))
        .foregroundStyle(scheme.accent)
        .frame(width: 22, alignment: .leading)
      Text(text)
        .font(BreatheFont.utility(14, weight: .regular))
        .foregroundStyle(scheme.ink)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Holding

  private var holdingContent: some View {
    TimelineView(.animation(minimumInterval: 0.1)) { context in
      let elapsed = max(0, context.date.timeIntervalSince(startDate))

      VStack(spacing: 0) {
        Spacer()

        Button(action: { stopHold(at: elapsed) }) {
          ZStack {
            Circle()
              .stroke(scheme.ink, lineWidth: 1)
              .frame(width: 264, height: 264)
            Text("\(Int(elapsed))")
              .font(BreatheFont.display(132, weight: .ultraLight))
              .foregroundStyle(scheme.ink)
              .monospacedDigit()
              .tracking(-4)
          }
          .frame(maxWidth: .infinity)
          .contentShape(Circle())
        }
        .buttonStyle(.plain)

        Text("Tap when you feel the first urge")
          .font(BreatheFont.utility(12, weight: .light))
          .foregroundStyle(scheme.muted)
          .tracking(3)
          .textCase(.uppercase)
          .padding(.top, 30)

        Spacer()

        Text("Seconds")
          .font(BreatheFont.utility(10, weight: .light))
          .foregroundStyle(scheme.muted)
          .tracking(3)
          .textCase(.uppercase)
          .padding(.bottom, 40)
      }
    }
  }

  // MARK: - Result

  private var resultContent: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("\(measured)")
        .font(BreatheFont.display(150, weight: .ultraLight))
        .foregroundStyle(scheme.ink)
        .monospacedDigit()
        .tracking(-6)

      Text("Seconds · BOLT")
        .font(BreatheFont.utility(11, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(3)
        .textCase(.uppercase)
        .padding(.top, 4)

      let reading = interpretation(for: measured)

      VStack(spacing: 10) {
        Text(reading.headline)
          .font(BreatheFont.display(22, weight: .regular, italic: true))
          .foregroundStyle(scheme.ink)
          .multilineTextAlignment(.center)

        Text(reading.detail)
          .font(BreatheFont.utility(13, weight: .light))
          .foregroundStyle(scheme.muted)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: 300)
      .padding(.top, 28)

      Spacer()

      Text("A comfort measure for breathing practice, not a medical test.")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 280)
        .padding(.bottom, 20)

      HStack(spacing: 30) {
        textControl("Measure again", action: startHold)
        textControl("Done", primary: true, action: onBack)
      }
      .padding(.bottom, 34)
    }
  }

  // MARK: - Controls

  private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(BreatheFont.display(19, weight: .regular, italic: true))
        .foregroundStyle(scheme.paper)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Capsule().fill(scheme.ink))
    }
    .buttonStyle(.plain)
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

  // MARK: - Logic

  private func startHold() {
    startDate = Date()
    stage = .holding
    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
  }

  private func stopHold(at elapsed: TimeInterval) {
    measured = Int(elapsed)
    lastBoltScore = measured
    lastBoltAt = Date().timeIntervalSince1970
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    stage = .result
  }

  private func interpretation(for seconds: Int) -> (headline: String, detail: String) {
    switch seconds {
    case ..<10:
      return (
        "Quite sensitive to CO2",
        "Favour slow, light, nasal breathing and eased holds. Light Breathing is a good place to start."
      )
    case 10..<20:
      return (
        "Building tolerance",
        "Light Breathing and the eased holds will gently extend your comfortable pause over time."
      )
    case 20..<30:
      return (
        "A steady, comfortable tolerance",
        "Most everyday practices will feel easy. Keep holds comfortable as you progress."
      )
    default:
      return (
        "Strong breath control",
        "You can explore longer holds and fuller patterns — still stopping well before any strain."
      )
    }
  }
}
