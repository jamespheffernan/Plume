# Plume / Breathe Clock

Plume is a native iPhone breathwork prototype built in SwiftUI. The repository is named Plume; the current Xcode target and on-device product name are **Breathe Clock**.

The app starts from the state a person wants to reach, then offers an appropriate routine, pace, duration, and sensory treatment. It covers gentle regulation, focus, energy, respiratory practice, contemplative work, and more intense guided sessions without presenting every technique as interchangeable or universally calming.

## Product highlights

- Goal-first routine discovery with a full browsable library
- Adjustable pacing and session duration
- Visual, audio, and haptic phase guidance
- Reduced-motion support and accessible labels
- Safety notes, intensity gates, grounding, and aftercare for stronger practices
- A local BOLT / Control Pause-style comfort assessment
- Several alternate app-icon themes
- Local settings with no account or backend

## Safety boundary

Breathe Clock is a general-wellbeing prototype, not medical advice or treatment. Rapid breathing and long retentions can cause dizziness, tingling, distress, or fainting. Strong routines should be practised only while seated or lying down, never in water, while driving, or while standing unsupported. Stop if a practice feels unsafe or forced.

## Build

Requirements:

- macOS with Xcode
- An iOS 17 or newer simulator or device

Open `BreatheClock.xcodeproj`, select the `BreatheClock` scheme, and run it on an iPhone target. The project definition is also retained in `project.yml` for XcodeGen users.

To verify a simulator build without code signing:

```bash
xcodebuild \
  -project BreatheClock.xcodeproj \
  -scheme BreatheClock \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Structure

- `BreatheClock/App` — application entry point and navigation
- `BreatheClock/Models` — routines, phases, safety content, and session models
- `BreatheClock/Views` — goal selection, library, setup, session, assessment, and settings
- `BreatheClock/Support` — theme and generated audio cues
- `docs` — breathwork context and the content-revision record

## Licence

No open-source licence has been selected. The source is public for inspection; default copyright rules apply.
