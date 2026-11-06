import SwiftUI

struct SetupView: View {
  let scheme: BreatheScheme
  let routine: Routine
  @Binding var selectedDuration: SessionDuration
  let onBack: () -> Void
  let onBegin: (Routine, SessionDuration) -> Void

  @AppStorage("boxSideSeconds") private var boxSideSeconds = BoxBreathLength.defaultSeconds
  @State private var showingSafetyGate = false
  @ScaledMetric(relativeTo: .headline) private var beginOpticalLift = 2.3
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                .font(BreatheFont.display(56, weight: .light, relativeTo: .largeTitle))
                .foregroundStyle(scheme.ink)
                .tracking(-1.1)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.55)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

              Text(activeRoutine.description)
                .font(BreatheFont.display(16, weight: .regular, relativeTo: .body))
                .foregroundStyle(scheme.ink)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                .lineSpacing(4)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 286)
                .padding(.bottom, 34)

              content

              if let source = activeRoutine.source {
                Text(source)
                  .font(BreatheFont.utility(13, weight: .regular, relativeTo: .footnote))
                  .foregroundStyle(scheme.muted)
                  .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                  .lineSpacing(3)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
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
            .font(BreatheFont.utility(12, weight: .regular, relativeTo: .subheadline))
            .tracking(2.1)
        }
        .textCase(.uppercase)
        .foregroundStyle(scheme.muted)
        .frame(minHeight: 44)
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
  @ViewBuilder
  private var detailedPatternBlock: some View {
    if dynamicTypeSize.isAccessibilitySize {
      // Phase labels must remain complete when their chosen text size no
      // longer fits a multi-column pattern. Keep each label beside its value.
      VStack(spacing: 12) {
        ForEach(Array(activeRoutine.phases.enumerated()), id: \.offset) { _, phase in
          HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(phase.label)
              .font(BreatheFont.utility(10, weight: .regular, relativeTo: .caption))
              .foregroundStyle(scheme.muted)
              .tracking(1)
              .textCase(.uppercase)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(phase.displaySeconds)
              .font(BreatheFont.display(56, weight: .ultraLight, relativeTo: .largeTitle))
              .foregroundStyle(scheme.ink)
              .monospacedDigit()
              .fixedSize()
          }
        }
      }
    } else {
      standardPatternGrid
    }
  }

  private var standardPatternGrid: some View {
    Grid(horizontalSpacing: 14, verticalSpacing: 11) {
      GridRow(alignment: .center) {
        ForEach(Array(activeRoutine.phases.enumerated()), id: \.offset) { index, phase in
          if index > 0 {
            Text("·")
              .font(BreatheFont.display(28, weight: .light, relativeTo: .largeTitle))
              .foregroundStyle(scheme.muted)
          }
          Text(phase.displaySeconds)
            .font(BreatheFont.display(56, weight: .ultraLight, relativeTo: .largeTitle))
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
            .font(BreatheFont.utility(10, weight: .light, relativeTo: .caption))
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
      // Preserve the compact summary at standard sizes; let the complete
      // sequence wrap when accessibility text no longer fits one line.
      Text(activeRoutine.patternText.replacingOccurrences(of: " · ", with: "\u{00A0}· "))
        .font(BreatheFont.display(30, weight: .light, relativeTo: .title))
        .foregroundStyle(scheme.ink)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.5)
        .fixedSize(horizontal: false, vertical: true)

      Text("Sequence")
        .font(BreatheFont.utility(10, weight: .light, relativeTo: .caption))
        .foregroundStyle(scheme.muted)
        .tracking(2.7)
        .textCase(.uppercase)
    }
  }

  private var programBlock: some View {
    VStack(spacing: 0) {
      ForEach(Array((activeRoutine.program ?? []).enumerated()), id: \.offset) { _, stage in
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            stageTitle(stage).fixedSize()
            Spacer(minLength: 10)
            stageDetails(stage).fixedSize()
          }
          VStack(alignment: .leading, spacing: 10) {
            stageTitle(stage)
            stageDetails(stage, patternAlignment: .leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
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

  private func stageTitle(_ stage: ProgramStage) -> some View {
    Text(stage.title)
      .font(BreatheFont.display(18, weight: .regular, relativeTo: .headline))
      .foregroundStyle(scheme.ink)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func stageDetails(_ stage: ProgramStage, patternAlignment: Alignment = .trailing) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(stagePattern(stage))
        .font(BreatheFont.display(14, weight: .light, relativeTo: .caption))
        .foregroundStyle(scheme.muted)
        .monospacedDigit()
        .fixedSize()
        .frame(minWidth: 86, maxWidth: .infinity, alignment: patternAlignment)

      Text(stage.duration.clockText)
        .font(BreatheFont.utility(11, weight: .regular, relativeTo: .caption))
        .foregroundStyle(scheme.muted)
        .monospacedDigit()
        .fixedSize()
        .frame(minWidth: 42, alignment: .trailing)
    }
  }

  private var untimedBlock: some View {
    VStack(spacing: 10) {
      Text("Untimed")
        .font(BreatheFont.display(42, weight: .light, relativeTo: .largeTitle))
        .foregroundStyle(scheme.ink)

      Text("Description only")
        .font(BreatheFont.utility(10, weight: .light, relativeTo: .caption))
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
        .font(BreatheFont.utility(10, weight: .light, relativeTo: .footnote))
        .foregroundStyle(scheme.muted)
        .tracking(1.5)
        .textCase(.uppercase)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
        .padding(.bottom, 20)

      beginButton("Begin")
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
    }
  }

  private var durationPicker: some View {
    VStack(spacing: 15) {
      Text(activeRoutine.durationControlTitle)
        .font(BreatheFont.utility(10, weight: .regular, relativeTo: .headline))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      pickerLayout {
        ForEach(activeRoutine.durationOptions) { option in
          Button {
            selectedDuration = option
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text(option.label)
                .font(BreatheFont.display(18, weight: .regular, relativeTo: .subheadline))
              if let unit = option.unit {
                Text(unit)
                  .font(BreatheFont.utility(10, weight: .regular, relativeTo: .subheadline))
                  .tracking(0.5)
              }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
            .foregroundStyle(selectedDuration == option ? scheme.ink : scheme.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(selectedDuration == option ? scheme.ink : Color.clear)
                .frame(height: 1)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(BreathePressStyle(pressedOpacity: 1))
          .accessibilityLabel(option.accessibilityLabel)
          .accessibilityAddTraits(selectedDuration == option ? .isSelected : [])
        }
      }

      if let helperText = durationHelperText {
        Text(helperText)
          .font(BreatheFont.utility(10, weight: .light, relativeTo: .footnote))
          .foregroundStyle(scheme.muted)
          .tracking(1.5)
          .textCase(.uppercase)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 2)
      }
    }
  }

  private var boxLengthPicker: some View {
    VStack(spacing: 12) {
      Text("Count")
        .font(BreatheFont.utility(10, weight: .regular, relativeTo: .headline))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      pickerLayout {
        ForEach(BoxBreathLength.options) { option in
          Button {
            boxSideSeconds = option.seconds
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text(option.label)
                .font(BreatheFont.display(18, weight: .regular, relativeTo: .subheadline))
              Text("s")
                .font(BreatheFont.utility(10, weight: .regular, relativeTo: .subheadline))
                .tracking(0.5)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
            .foregroundStyle(selectedBoxSideSeconds == option.seconds ? scheme.ink : scheme.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(selectedBoxSideSeconds == option.seconds ? scheme.ink : Color.clear)
                .frame(height: 1)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(BreathePressStyle(pressedOpacity: 1))
          .accessibilityLabel("\(option.seconds) seconds per side")
          .accessibilityAddTraits(selectedBoxSideSeconds == option.seconds ? .isSelected : [])
        }
      }
      .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 236)
    }
  }

  // Stack options at accessibility sizes so every label can use the selected
  // system size. Standard sizes retain the original compact, underlined row.
  private var pickerLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 5))
      : AnyLayout(HStackLayout(spacing: 5))
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
      BreatheButtonText(title: title, font: BreatheFont.display(19, weight: .regular, relativeTo: .headline))
        .offset(y: -beginOpticalLift)
        .padding(.horizontal, 48)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64)
        .overlay(alignment: .trailing) {
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .padding(.trailing, 26)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .foregroundStyle(scheme.paper)
        .background(Capsule().fill(scheme.ink))
        .contentShape(Capsule())
    }
    .buttonStyle(BreathePressStyle())
    .accessibilityLabel("\(title), \(activeRoutine.name)")
  }

  private var descriptionOnlyFooter: some View {
    Text("No timed cycle yet")
      .font(BreatheFont.utility(11, weight: .medium, relativeTo: .subheadline))
      .foregroundStyle(scheme.ink)
      .tracking(3)
      .textCase(.uppercase)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 64)
      .overlay {
        Capsule()
          .stroke(scheme.hairline, lineWidth: 1)
      }
  }

  private func safetyNoteBlock(_ note: String) -> some View {
    Text(note)
      .font(BreatheFont.utility(13, weight: .regular, relativeTo: .footnote))
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
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Before you begin")
            .font(BreatheFont.display(30, weight: .light, relativeTo: .title))
            .foregroundStyle(scheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)

          Text(BreatheSafety.intenseRules)
            .font(BreatheFont.utility(15, weight: .regular, relativeTo: .body))
            .foregroundStyle(scheme.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

          if let note = activeRoutine.safetyNote {
            Text(note)
              .font(BreatheFont.utility(15, weight: .regular, relativeTo: .body))
              .foregroundStyle(scheme.muted)
              .lineSpacing(4)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
      }
      .scrollIndicators(.hidden)

      VStack(spacing: 14) {
        Button {
          showingSafetyGate = false
          onBegin(activeRoutine, selectedDuration)
        } label: {
          Text("I understand — begin")
            .font(BreatheFont.display(18, weight: .regular, relativeTo: .headline))
            .foregroundStyle(scheme.paper)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Capsule().fill(scheme.ink))
        }
        .buttonStyle(BreathePressStyle())

        Button {
          showingSafetyGate = false
        } label: {
          BreatheButtonText(title: "Not now", font: BreatheFont.utility(11, weight: .medium, relativeTo: .subheadline), tracking: 3, uppercase: true)
            .foregroundStyle(scheme.muted)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(BreathePressStyle(pressedOpacity: 1))
      }
      .padding(.top, 18)
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper)
  }
}
