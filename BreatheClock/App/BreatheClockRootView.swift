import SwiftUI

struct BreatheClockRootView: View {
  @AppStorage("scheme") private var schemeRawValue = BreatheScheme.sepiaClay.rawValue
  @AppStorage("audio") private var audioRawValue = AudioCue.bowl.rawValue
  @AppStorage("haptics") private var hapticsEnabled = true
  @AppStorage("hapticsBreathSwell") private var swellHapticsEnabled = true
  @AppStorage("lastRoutine") private var lastRoutineID = Routine.coherence.id
  @AppStorage("durationSeconds") private var durationSeconds = 180
  @AppStorage("didAcknowledgeSafety") private var didAcknowledgeSafety = false

  @State private var route: AppRoute = .library
  @State private var selectedRoutine = Routine.coherence
  @State private var sessionRoutine = Routine.coherence
  @State private var showSafety = false
  // The staggered launch settle plays once, on the first cold-launch appearance
  // of the Library — not when returning from Setup/Settings, and never for the
  // direct-route test hooks (so scripted screenshots stay stable).
  @State private var hasPlayedLaunchEntrance = false
  @State private var suppressLaunchEntrance = false
  // Settings opens as a sheet over a running session (issue #3) so dismissing
  // returns to the breathing screen without tearing the session down.
  @State private var showSettingsSheet = false

  var body: some View {
    ZStack {
      activeScheme.paper.ignoresSafeArea()

      switch route {
      case .library:
        LibraryView(
          scheme: activeScheme,
          selectedRoutine: selectedRoutine,
          onSelectRoutine: { routine in
            selectedRoutine = routine
            lastRoutineID = routine.id
            navigate(to: .setup)
          },
          onSettings: { navigate(to: .settings) },
          animateEntrance: !hasPlayedLaunchEntrance && !suppressLaunchEntrance,
          onEntrancePlayed: { hasPlayedLaunchEntrance = true }
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
            navigate(to: .session)
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
          swellHapticsEnabled: swellHapticsEnabled,
          onEnd: { navigate(to: .setup) },
          onSettings: { showSettingsSheet = true }
        )
        .transition(.opacity)

      case .settings:
        SettingsView(
          scheme: activeScheme,
          schemeSelection: schemeBinding,
          audioCue: audioBinding,
          hapticsEnabled: $hapticsEnabled,
          swellHapticsEnabled: $swellHapticsEnabled,
          onBack: { navigate(to: .library) }
        )
        .transition(.opacity)
      }
    }
    // Dark schemes (e.g. Indigo Vat) need the light status bar / system chrome.
    .preferredColorScheme(activeScheme.inverted ? .dark : .light)
    .fullScreenCover(isPresented: $showSafety) {
      SafetyOnboardingView(scheme: activeScheme) {
        didAcknowledgeSafety = true
        showSafety = false
      }
    }
    // Settings reachable from the breathing screen (issue #3): presented over
    // the live session so the breath keeps its place and returns on dismiss.
    .sheet(isPresented: $showSettingsSheet) {
      SettingsView(
        scheme: activeScheme,
        schemeSelection: schemeBinding,
        audioCue: audioBinding,
        hapticsEnabled: $hapticsEnabled,
        swellHapticsEnabled: $swellHapticsEnabled,
        onBack: { showSettingsSheet = false }
      )
      .preferredColorScheme(activeScheme.inverted ? .dark : .light)
    }
    .task {
      selectedRoutine = Routine.byID(lastRoutineID) ?? .coherence
      sessionRoutine = selectedRoutine
      route = .library
      showSafety = !didAcknowledgeSafety
      // Testing hook: force a colour scheme so each palette can be screenshotted
      // without tapping through Settings (env survives relaunch more reliably
      // than a simctl `defaults write`).
      if let schemeName = ProcessInfo.processInfo.environment["BC_SCHEME"],
         let forced = BreatheScheme(rawValue: schemeName) {
        schemeRawValue = forced.rawValue
      }
      // Testing hook: jump straight to a screen so each route can be verified
      // (e.g. Dynamic Type screenshots) without scripted taps.
      if let routeName = ProcessInfo.processInfo.environment["BC_DIRECT_ROUTE"] {
        suppressLaunchEntrance = true
        showSafety = false
        switch routeName {
        case "setup": route = .setup
        case "session": route = .session
        case "settings": route = .settings
        default: route = .library
        }
      }
      if let direct = ProcessInfo.processInfo.environment["BC_DIRECT_SESSION"] {
        suppressLaunchEntrance = true
        selectedRoutine = Routine.byID(direct) ?? .coherence
        sessionRoutine = selectedRoutine
        showSafety = false
        route = .session
      }
    }
  }

  private var activeScheme: BreatheScheme {
    BreatheScheme(rawValue: schemeRawValue) ?? .sepiaClay
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
  case library
  case setup
  case session
  case settings
}

private struct SafetyOnboardingView: View {
  let scheme: BreatheScheme
  let onAcknowledge: () -> Void

  var body: some View {
    // Centred at normal text sizes; scrolls once the disclaimer grows past one
    // screen so the acknowledge button is always reachable at large sizes.
    GeometryReader { geo in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Spacer(minLength: 40)

          Text("Plume")
            .font(BreatheFont.display(40, weight: .light, italic: true))
            .foregroundStyle(scheme.ink)

          Text("A note on safety")
            .font(BreatheFont.utility(11, weight: .medium))
            .foregroundStyle(scheme.muted)
            .tracking(3)
            .textCase(.uppercase)
            .padding(.top, 10)
            .padding(.bottom, 26)

          Text(BreatheSafety.disclaimer)
            .font(BreatheFont.utility(15, weight: .regular))
            .foregroundStyle(scheme.ink)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)

          Spacer(minLength: 24)

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
        .frame(minHeight: geo.size.height)
      }
      .scrollIndicators(.hidden)
      .scrollBounceBehavior(.basedOnSize)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(scheme.paper.ignoresSafeArea())
  }
}
