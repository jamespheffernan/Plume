import SwiftUI

struct SetupView: View {
  let scheme: BreatheScheme
  let routine: Routine
  @Binding var selectedDuration: SessionDuration
  let onBack: () -> Void
  let onBegin: (Routine) -> Void

  @State private var showingSafetyGate = false
  @State private var pace: BreathPace = .full

  /// The routine actually launched — eased pattern swapped in when chosen.
  private var resolvedRoutine: Routine {
    routine.resolved(for: pace)
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
        .padding(.horizontal, 24)
        .padding(.top, 24)

      Spacer(minLength: 30)

      VStack(spacing: 0) {
        Text(routine.name)
          .font(BreatheFont.display(56, weight: .light, italic: true))
          .foregroundStyle(scheme.ink)
          .tracking(-1.1)
          .lineLimit(1)
          .minimumScaleFactor(0.55)
          .padding(.bottom, 16)

        Text(routine.description)
          .font(BreatheFont.display(16, weight: .regular))
          .foregroundStyle(scheme.ink)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .frame(maxWidth: 286)
          .padding(.bottom, 34)

        content
      }
      .padding(.horizontal, 28)

      Spacer(minLength: 24)

      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
    .animation(.easeInOut(duration: 0.25), value: pace)
    .sheet(isPresented: $showingSafetyGate) {
      safetyGateView
    }
  }

  private var topBar: some View {
    HStack {
      Button(action: onBack) {
        HStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 12, weight: .semibold))
          Text("Library")
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

  // MARK: - Content (the routine's shape)

  @ViewBuilder
  private var content: some View {
    if routine.mode == .assessment {
      assessmentBlock
    } else if routine.isProgram {
      programBlock
    } else if routine.isTimed {
      patternBlock
    } else {
      untimedBlock
    }
  }

  @ViewBuilder
  private var patternBlock: some View {
    if resolvedRoutine.phases.count > 6 {
      compactPatternBlock
    } else {
      detailedPatternBlock
    }
  }

  private var detailedPatternBlock: some View {
    VStack(spacing: 11) {
      HStack(alignment: .firstTextBaseline, spacing: 18) {
        ForEach(Array(resolvedRoutine.phases.enumerated()), id: \.offset) { index, phase in
          if index > 0 {
            Text("·")
              .font(BreatheFont.display(28, weight: .light))
              .foregroundStyle(scheme.muted)
              .baselineOffset(8)
          }
          Text(phase.displaySeconds)
            .font(BreatheFont.display(56, weight: .ultraLight))
            .foregroundStyle(scheme.ink)
            .monospacedDigit()
            .minimumScaleFactor(0.72)
        }
      }
      .lineLimit(1)

      HStack(spacing: 22) {
        ForEach(Array(resolvedRoutine.phases.enumerated()), id: \.offset) { _, phase in
          Text(phase.label)
            .font(BreatheFont.utility(10, weight: .light))
            .foregroundStyle(scheme.muted)
            .tracking(2.7)
            .textCase(.uppercase)
            .frame(minWidth: 52)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.65)
    }
  }

  private var compactPatternBlock: some View {
    VStack(spacing: 12) {
      Text(resolvedRoutine.patternText)
        .font(BreatheFont.display(34, weight: .light))
        .foregroundStyle(scheme.ink)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.58)

      Text("Sequence")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(2.7)
        .textCase(.uppercase)
    }
  }

  private var programBlock: some View {
    VStack(spacing: 0) {
      ForEach(Array((routine.program ?? []).enumerated()), id: \.offset) { _, stage in
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(stage.title)
            .font(BreatheFont.display(18, weight: .regular, italic: true))
            .foregroundStyle(scheme.ink)

          Spacer(minLength: 10)

          Text(stagePattern(stage))
            .font(BreatheFont.display(14, weight: .light))
            .foregroundStyle(scheme.muted)
            .monospacedDigit()

          Text(stage.duration.clockText)
            .font(BreatheFont.utility(11, weight: .regular))
            .foregroundStyle(scheme.muted)
            .monospacedDigit()
            .frame(width: 42, alignment: .trailing)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(scheme.hairline)
            .frame(height: 1)
        }
      }
    }
  }

  private var assessmentBlock: some View {
    VStack(alignment: .leading, spacing: 16) {
      assessmentStep("1", "Breathe normally, then exhale gently.")
      assessmentStep("2", "Hold, and start the timer.")
      assessmentStep("3", "Stop at the first clear urge to breathe.")
    }
    .frame(maxWidth: 300)
  }

  private func assessmentStep(_ number: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number)
        .font(BreatheFont.display(20, weight: .light, italic: true))
        .foregroundStyle(scheme.accent)
        .frame(width: 20, alignment: .leading)
      Text(text)
        .font(BreatheFont.utility(14, weight: .regular))
        .foregroundStyle(scheme.ink)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var untimedBlock: some View {
    VStack(spacing: 10) {
      Text("Untimed")
        .font(BreatheFont.display(42, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)

      Text("Description only")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(2.7)
        .textCase(.uppercase)
    }
  }

  private func stagePattern(_ stage: ProgramStage) -> String {
    stage.phases.map { $0.displaySeconds }.joined(separator: " · ")
  }

  // MARK: - Footer (controls)

  @ViewBuilder
  private var footer: some View {
    if routine.mode == .assessment {
      assessmentFooter
    } else if routine.isProgram {
      programFooter
    } else if routine.isTimed {
      timedFooter
    } else {
      descriptionOnlyFooter
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
  }

  private var timedFooter: some View {
    VStack(spacing: 0) {
      if routine.hasReducedVariant {
        paceSelector
          .padding(.horizontal, 24)
          .padding(.bottom, 22)
      }

      durationPicker
        .padding(.horizontal, 24)
        .padding(.bottom, 24)

      if let note = routine.safetyNote, !routine.requiresAcknowledgement {
        safetyNoteBlock(note)
      }

      beginButton("Begin")
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
  }

  private var programFooter: some View {
    VStack(spacing: 0) {
      Text("Completes at \(routine.programTotalDuration.clockText)")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(1.5)
        .textCase(.uppercase)
        .padding(.bottom, 20)

      beginButton("Begin")
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
  }

  private var assessmentFooter: some View {
    VStack(spacing: 0) {
      if let note = routine.safetyNote {
        safetyNoteBlock(note)
      }

      beginButton("Begin measurement")
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
    }
  }

  private var paceSelector: some View {
    VStack(spacing: 12) {
      Text("Pace")
        .font(BreatheFont.utility(10, weight: .regular))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      HStack(spacing: 5) {
        ForEach(BreathPace.allCases) { option in
          Button {
            pace = option
          } label: {
            Text(option.label)
              .font(BreatheFont.display(18, weight: pace == option ? .regular : .light))
              .foregroundStyle(pace == option ? scheme.ink : scheme.muted)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .overlay(alignment: .bottom) {
                Rectangle()
                  .fill(pace == option ? scheme.ink : Color.clear)
                  .frame(height: 1)
              }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(option.label) pace")
        }
      }

      Text(pace == .eased ? "Shorter holds while you build tolerance" : "The full pattern")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(1.5)
        .textCase(.uppercase)
        .padding(.top, 2)
    }
  }

  private var durationPicker: some View {
    VStack(spacing: 15) {
      Text("Duration")
        .font(BreatheFont.utility(10, weight: .regular))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      HStack(spacing: 5) {
        ForEach(SessionDuration.options) { option in
          Button {
            selectedDuration = option
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
              Text(option.label)
                .font(BreatheFont.display(18, weight: selectedDuration == option ? .regular : .light))
              if let unit = option.unit {
                Text(unit)
                  .font(BreatheFont.utility(10, weight: .regular))
                  .tracking(0.8)
                  .textCase(.uppercase)
              }
            }
            .foregroundStyle(selectedDuration == option ? scheme.ink : scheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(selectedDuration == option ? scheme.ink : Color.clear)
                .frame(height: 1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(option.seconds == nil ? "Infinite" : "\(option.label) minutes")
        }
      }

      if let alignmentText = resolvedRoutine.alignmentText(for: selectedDuration) {
        Text(alignmentText)
          .font(BreatheFont.utility(10, weight: .light))
          .foregroundStyle(scheme.muted)
          .tracking(1.5)
          .textCase(.uppercase)
          .padding(.top, 2)
      } else if resolvedRoutine.hasHoldPhases {
        Text("Audio plays for hold phases too")
          .font(BreatheFont.utility(10, weight: .light))
          .foregroundStyle(scheme.muted)
          .tracking(1.5)
          .textCase(.uppercase)
          .padding(.top, 2)
      }
    }
  }

  private func beginButton(_ title: String) -> some View {
    Button(action: handleBegin) {
      HStack(spacing: 12) {
        Text(title)
          .font(BreatheFont.display(19, weight: .regular, italic: true))
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
      }
      .foregroundStyle(scheme.paper)
      .frame(maxWidth: .infinity)
      .frame(height: 64)
      .background(Capsule().fill(scheme.ink))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title), \(routine.name)")
  }

  private var descriptionOnlyFooter: some View {
    Text("No timed cycle yet")
      .font(BreatheFont.utility(11, weight: .medium))
      .foregroundStyle(scheme.ink)
      .tracking(3)
      .textCase(.uppercase)
      .frame(maxWidth: .infinity)
      .frame(height: 64)
      .overlay {
        Capsule()
          .stroke(scheme.hairline, lineWidth: 1)
      }
  }

  private func safetyNoteBlock(_ note: String) -> some View {
    Text(note)
      .font(BreatheFont.utility(11, weight: .light))
      .foregroundStyle(scheme.muted)
      .multilineTextAlignment(.center)
      .lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: 300)
      .padding(.horizontal, 24)
      .padding(.bottom, 22)
  }

  private func handleBegin() {
    if routine.requiresAcknowledgement {
      showingSafetyGate = true
    } else {
      onBegin(resolvedRoutine)
    }
  }

  private var safetyGateView: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Before you begin")
        .font(BreatheFont.display(30, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .padding(.top, 40)
        .padding(.bottom, 22)

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(BreatheSafety.intenseRules)
            .font(BreatheFont.utility(13, weight: .regular))
            .foregroundStyle(scheme.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

          if let note = routine.safetyNote {
            Text(note)
              .font(BreatheFont.utility(13, weight: .light))
              .foregroundStyle(scheme.muted)
              .lineSpacing(4)
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(alignment: .leading, spacing: 7) {
            Text("Avoid or seek advice with")
              .font(BreatheFont.utility(10, weight: .medium))
              .foregroundStyle(scheme.muted)
              .tracking(2.4)
              .textCase(.uppercase)
            ForEach(BreatheSafety.contraindications, id: \.self) { item in
              Text("— \(item)")
                .font(BreatheFont.utility(13, weight: .light))
                .foregroundStyle(scheme.ink)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)

      VStack(spacing: 14) {
        Button {
          showingSafetyGate = false
          onBegin(resolvedRoutine)
        } label: {
          Text("I understand — begin")
            .font(BreatheFont.display(18, weight: .regular, italic: true))
            .foregroundStyle(scheme.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Capsule().fill(scheme.ink))
        }
        .buttonStyle(.plain)

        Button {
          showingSafetyGate = false
        } label: {
          Text("Not now")
            .font(BreatheFont.utility(11, weight: .medium))
            .foregroundStyle(scheme.muted)
            .tracking(3)
            .textCase(.uppercase)
            .frame(height: 30)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 18)
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
  }
}
