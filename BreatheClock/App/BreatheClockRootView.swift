import SwiftUI

struct BreatheClockRootView: View {
  @AppStorage("scheme") private var schemeRawValue = BreatheScheme.charcoal.rawValue
  @AppStorage("audio") private var audioRawValue = AudioCue.bowl.rawValue
  @AppStorage("haptics") private var hapticsEnabled = true
  @AppStorage("lastRoutine") private var lastRoutineID = Routine.coherence.id
  @AppStorage("durationSeconds") private var durationSeconds = 180
  @AppStorage("didAcknowledgeSafety") private var didAcknowledgeSafety = false
  @AppStorage("startOnGoals") private var startOnGoals = true

  @State private var route: AppRoute = .goal
  @State private var selectedRoutine = Routine.coherence
  @State private var sessionRoutine = Routine.coherence
  @State private var focusedCategory: String?
  @State private var showSafety = false

  var body: some View {
    ZStack {
      activeScheme.paper.ignoresSafeArea()

      switch route {
      case .goal:
        GoalEntryView(
          scheme: activeScheme,
          onChooseCategory: { category in
            focusedCategory = category
            navigate(to: .library)
          },
          onBrowseAll: {
            focusedCategory = nil
            navigate(to: .library)
          },
          onSettings: { navigate(to: .settings) }
        )
        .transition(.opacity)

      case .library:
        LibraryView(
          scheme: activeScheme,
          selectedRoutine: selectedRoutine,
          focusedCategory: focusedCategory,
          onSelectRoutine: { routine in
            selectedRoutine = routine
            lastRoutineID = routine.id
            navigate(to: .setup)
          },
          onShowAll: { withAnimation(.easeInOut(duration: 0.25)) { focusedCategory = nil } },
          onGoals: { navigate(to: .goal) },
          onSettings: { navigate(to: .settings) }
        )
        .transition(.opacity)

      case .setup:
        SetupView(
          scheme: activeScheme,
          routine: selectedRoutine,
          selectedDuration: durationBinding,
          onBack: { navigate(to: .library) },
          onBegin: { resolved in
            sessionRoutine = resolved
            navigate(to: resolved.mode == .assessment ? .assessment : .session)
          }
        )
        .transition(.opacity)

      case .session:
        SessionView(
          scheme: activeScheme,
          routine: sessionRoutine,
          duration: durationBinding.wrappedValue,
          audioCue: activeAudioCue,
          hapticsEnabled: hapticsEnabled,
          onEnd: { navigate(to: .setup) }
        )
        .transition(.opacity)

      case .assessment:
        AssessmentView(
          scheme: activeScheme,
          routine: sessionRoutine,
          onBack: { navigate(to: .setup) }
        )
        .transition(.opacity)

      case .settings:
        SettingsView(
          scheme: activeScheme,
          schemeSelection: schemeBinding,
          audioCue: audioBinding,
          hapticsEnabled: $hapticsEnabled,
          startOnGoals: $startOnGoals,
          onBack: { navigate(to: startOnGoals ? .goal : .library) }
        )
        .transition(.opacity)
      }
    }
    .preferredColorScheme(.light)
    .fullScreenCover(isPresented: $showSafety) {
      SafetyOnboardingView(scheme: activeScheme) {
        didAcknowledgeSafety = true
        showSafety = false
      }
    }
    .task {
      selectedRoutine = Routine.byID(lastRoutineID) ?? .coherence
      sessionRoutine = selectedRoutine
      route = startOnGoals ? .goal : .library
      showSafety = !didAcknowledgeSafety
    }
  }

  private var activeScheme: BreatheScheme {
    BreatheScheme(rawValue: schemeRawValue) ?? .charcoal
  }

  private var activeAudioCue: AudioCue {
    AudioCue(rawValue: audioRawValue) ?? .bowl
  }

  private var durationBinding: Binding<SessionDuration> {
    Binding(
      get: { SessionDuration.fromStored(seconds: durationSeconds) },
      set: { durationSeconds = $0.storedSeconds }
    )
  }

  private var schemeBinding: Binding<BreatheScheme> {
    Binding(
      get: { activeScheme },
      set: { schemeRawValue = $0.rawValue }
    )
  }

  private var audioBinding: Binding<AudioCue> {
    Binding(
      get: { activeAudioCue },
      set: { audioRawValue = $0.rawValue }
    )
  }

  private func navigate(to route: AppRoute) {
    withAnimation(.easeInOut(duration: 0.32)) {
      self.route = route
    }
  }
}

private enum AppRoute {
  case goal
  case library
  case setup
  case session
  case assessment
  case settings
}

private struct SafetyOnboardingView: View {
  let scheme: BreatheScheme
  let onAcknowledge: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 40)

      Text("Breathe")
        .font(BreatheFont.display(40, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)

      Text("A note on safety")
        .font(BreatheFont.utility(11, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(3)
        .textCase(.uppercase)
        .padding(.top, 10)
        .padding(.bottom, 26)

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(BreatheSafety.disclaimer)
            .font(BreatheFont.utility(14, weight: .regular))
            .foregroundStyle(scheme.ink)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)

          Text(BreatheSafety.intenseRules)
            .font(BreatheFont.utility(13, weight: .light))
            .foregroundStyle(scheme.muted)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

          VStack(alignment: .leading, spacing: 7) {
            Text("Take extra care with")
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

      Button(action: onAcknowledge) {
        Text("I understand")
          .font(BreatheFont.display(18, weight: .regular, italic: true))
          .foregroundStyle(scheme.paper)
          .frame(maxWidth: .infinity)
          .frame(height: 62)
          .background(Capsule().fill(scheme.ink))
      }
      .buttonStyle(.plain)
      .padding(.top, 20)

      Spacer(minLength: 24)
    }
    .padding(.horizontal, 30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper.ignoresSafeArea())
  }
}
