import SwiftUI

struct SetupView: View {
  let scheme: BreatheScheme
  let routine: Routine
  @Binding var selectedDuration: SessionDuration
  let onBack: () -> Void
  let onBegin: (Routine, SessionDuration) -> Void

  @AppStorage("boxSideSeconds") private var boxSideSeconds = BoxBreathLength.defaultSeconds
  @State private var showingSafetyGate = false

  private var selectedBoxSideSeconds: Int {
    BoxBreathLength.normalizedSeconds(boxSideSeconds)
  }

  private var activeRoutine: Routine {
    routine.withBoxSideSeconds(selectedBoxSideSeconds)
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
        .padding(.horizontal, 28)
        .padding(.top, 24)

      // The body stays a centred composition at normal text sizes (Spacers fill
      // the screen), but scrolls once Dynamic Type grows it past one screen, so
      // the title and Begin button never clip at accessibility sizes.
      GeometryReader { geo in
        ScrollView {
          VStack(spacing: 0) {
            Spacer(minLength: 30)

            VStack(spacing: 0) {
              Text(activeRoutine.name)
                .font(BreatheFont.display(56, weight: .light, italic: true))
                .foregroundStyle(scheme.ink)
                .tracking(-1.1)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.bottom, 16)

              Text(activeRoutine.description)
                .font(BreatheFont.display(16, weight: .regular))
                .foregroundStyle(scheme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 286)
                .padding(.bottom, 34)

              content

              if let source = activeRoutine.source {
                Text(source)
                  .font(BreatheFont.utility(11, weight: .light))
                  .foregroundStyle(scheme.muted)
                  .multilineTextAlignment(.center)
                  .lineSpacing(3)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: 300)
                  .padding(.top, 26)
              }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 24)

            footer
          }
          .frame(minHeight: geo.size.height)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
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
    if activeRoutine.isProgram {
      programBlock
    } else if activeRoutine.isTimed {
      VStack(spacing: routine.supportsBoxLengthControl ? 24 : 0) {
        patternBlock
        if routine.supportsBoxLengthControl {
          boxLengthPicker
        }
      }
    } else {
      untimedBlock
    }
  }

  @ViewBuilder
  private var patternBlock: some View {
    if activeRoutine.phases.count > 6 {
      compactPatternBlock
    } else {
      detailedPatternBlock
    }
  }

  /// Each numeral sits in the same Grid column as its label, so the two always
  /// share a center by construction; the separator dots live in their own
  /// (label-less) columns between them.
  private var detailedPatternBlock: some View {
    Grid(horizontalSpacing: 14, verticalSpacing: 11) {
      GridRow(alignment: .center) {
        ForEach(Array(activeRoutine.phases.enumerated()), id: \.offset) { index, phase in
          if index > 0 {
            Text("·")
              .font(BreatheFont.display(28, weight: .light))
              .foregroundStyle(scheme.muted)
          }
          Text(phase.displaySeconds)
            .font(BreatheFont.display(56, weight: .ultraLight))
            .foregroundStyle(scheme.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
      }

      GridRow {
        ForEach(Array(activeRoutine.phases.enumerated()), id: \.offset) { index, phase in
          if index > 0 {
            Color.clear.frame(width: 1, height: 0)
          }
          Text(phase.label)
            .font(BreatheFont.utility(10, weight: .light))
            .foregroundStyle(scheme.muted)
            .tracking(2.7)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
      }
    }
  }

  private var compactPatternBlock: some View {
    VStack(spacing: 12) {
      // One line that scales to fit, so the " · " separators never wrap and
      // strand a dot at the start of a line.
      Text(activeRoutine.patternText)
        .font(BreatheFont.display(30, weight: .light))
        .foregroundStyle(scheme.ink)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.5)

      Text("Sequence")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(2.7)
        .textCase(.uppercase)
    }
  }

  private var programBlock: some View {
    VStack(spacing: 0) {
      ForEach(Array((activeRoutine.program ?? []).enumerated()), id: \.offset) { _, stage in
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(stage.title)
            .font(BreatheFont.display(18, weight: .regular, italic: true))
            .foregroundStyle(scheme.ink)

          Spacer(minLength: 10)

          Text(stagePattern(stage))
            .font(BreatheFont.display(14, weight: .light))
            .foregroundStyle(scheme.muted)
            .monospacedDigit()
            .frame(minWidth: 86, alignment: .trailing)

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
    if activeRoutine.isProgram {
      programFooter
    } else if activeRoutine.isTimed {
      timedFooter
    } else {
      descriptionOnlyFooter
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }
  }

  private var timedFooter: some View {
    VStack(spacing: 0) {
      durationPicker
        .padding(.horizontal, 28)
        .padding(.bottom, 24)

      if let note = activeRoutine.safetyNote, !activeRoutine.requiresAcknowledgement {
        safetyNoteBlock(note)
      }

      beginButton("Begin")
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }
  }

  private var programFooter: some View {
    VStack(spacing: 0) {
      Text("Completes at \(activeRoutine.programTotalDuration.clockText)")
        .font(BreatheFont.utility(10, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(1.5)
        .textCase(.uppercase)
        .padding(.bottom, 20)

      beginButton("Begin")
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }
  }

  private var durationPicker: some View {
    VStack(spacing: 15) {
      Text(activeRoutine.durationControlTitle)
        .font(BreatheFont.utility(10, weight: .regular))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      HStack(spacing: 5) {
        ForEach(activeRoutine.durationOptions) { option in
          Button {
            selectedDuration = option
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text(option.label)
                .font(BreatheFont.display(18, weight: selectedDuration == option ? .regular : .light))
              if let unit = option.unit {
                Text(unit)
                  .font(BreatheFont.utility(10, weight: .regular))
                  .tracking(0.5)
              }
            }
            .lineLimit(1)
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
          .accessibilityLabel(option.accessibilityLabel)
          .accessibilityAddTraits(selectedDuration == option ? .isSelected : [])
        }
      }
      // Six fixed options in one row can't widen, so cap their growth; the
      // surrounding labels and copy still scale freely.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

      if let helperText = durationHelperText {
        Text(helperText)
          .font(BreatheFont.utility(10, weight: .light))
          .foregroundStyle(scheme.muted)
          .tracking(1.5)
          .textCase(.uppercase)
          .padding(.top, 2)
      }
    }
  }

  private var boxLengthPicker: some View {
    VStack(spacing: 12) {
      Text("Count")
        .font(BreatheFont.utility(10, weight: .regular))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      HStack(spacing: 5) {
        ForEach(BoxBreathLength.options) { option in
          Button {
            boxSideSeconds = option.seconds
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text(option.label)
                .font(BreatheFont.display(18, weight: selectedBoxSideSeconds == option.seconds ? .regular : .light))
              Text("s")
                .font(BreatheFont.utility(10, weight: .regular))
                .tracking(0.5)
            }
            .lineLimit(1)
            .foregroundStyle(selectedBoxSideSeconds == option.seconds ? scheme.ink : scheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(selectedBoxSideSeconds == option.seconds ? scheme.ink : Color.clear)
                .frame(height: 1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(option.seconds) seconds per side")
          .accessibilityAddTraits(selectedBoxSideSeconds == option.seconds ? .isSelected : [])
        }
      }
      .frame(maxWidth: 236)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
  }

  private var durationHelperText: String? {
    if activeRoutine.id == "wim-hof",
       let seconds = activeRoutine.alignedSessionDuration(for: selectedDuration) {
      return "Completes at \(seconds.clockText)"
    }
    if let alignmentText = activeRoutine.alignmentText(for: selectedDuration) {
      return alignmentText
    }
    if activeRoutine.hasHoldPhases {
      return "Audio plays for hold phases too"
    }
    return nil
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
    .accessibilityLabel("\(title), \(activeRoutine.name)")
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
      .padding(.horizontal, 28)
      .padding(.bottom, 22)
  }

  private func handleBegin() {
    if activeRoutine.requiresAcknowledgement {
      showingSafetyGate = true
    } else {
      onBegin(activeRoutine, selectedDuration)
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

          if let note = activeRoutine.safetyNote {
            Text(note)
              .font(BreatheFont.utility(13, weight: .light))
              .foregroundStyle(scheme.muted)
              .lineSpacing(4)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)

      VStack(spacing: 14) {
        Button {
          showingSafetyGate = false
          onBegin(activeRoutine, selectedDuration)
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
