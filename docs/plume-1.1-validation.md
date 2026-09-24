# Plume 1.1 — build and device validation

Built locally on 24 September 2026. Scope: four-tone sound-preview progression, “A Turf Terrace product”, “Cambridge, UK”, and legitimate background breathing audio. Watch, Health and ratings are excluded. James subsequently approved committing/pushing, release signing and TestFlight delivery. Public App Store submission remains excluded.

## Behaviour

- The selected sound row shows four small bars. They advance with the actual played preview buffers, then disappear. Choosing another sound or Off, leaving Settings, backgrounding, an interruption, or disconnecting headphones cancels the preview.
- Sessions queue the countdown, complete breathing cycles or guided stages, and a finite completion tone before playback. Finite sessions stop without a foreground timer. Infinite sessions loop their audible breathing cycle. Repeated cycles share buffers.
- With audio enabled, playback and its clock continue while locked/backgrounded. The onscreen breathing guide follows the audio clock. Silence between phase cues belongs to the breathing guide; there is no silent keepalive for Audio Off.
- With Audio Off, backgrounding pauses the session. Haptics run only while Plume is active. Preparing audio is paused if the app backgrounds before playback starts.
- Pause, End and Restart cancel queued audio. Resume rebuilds the remaining score from the saved position, not from the start of the breath. Calls, headphone disconnection and audio-engine configuration changes pause an active session; Resume is explicit, never automatic.
- First-session breathing primer does not start session audio until Begin. Audio activation/rendering failure leaves the session paused with a retry message.
- Version is 1.1.0. The repository's default build number is 1; the release pipeline assigns a unique timestamp build number when archiving for TestFlight.

## Automated checks

Xcode 27.0, iOS 26.5 simulator “Plume 1.1 Verification”. No third-party dependencies or configured linter.

```sh
xcodegen generate
xcrun simctl list devices available
xcodebuild -project BreatheClock.xcodeproj -scheme BreatheClock \
  -destination 'platform=iOS Simulator,name=Plume 1.1 Verification,OS=26.5' \
  -derivedDataPath build/Plume11 -parallel-testing-enabled NO \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

Use an available iPhone simulator's name/OS or UDID on another machine. The iOS 27.0 beta runtime ran assertions but sometimes failed to return from test shutdown; the stable 26.5 runtime completed normally.

Coverage: 18 model/real-audio-player/session-hosting tests and four UI tests. Includes all routine/duration combinations, program stage clipping, infinite and mid-countdown resume, preview sequence/cancellation, finite completion without a view timer, queued completion cancellation, Audio Off, About text/version, background audible playback and silent pause/resume. Tests use the actual AVAudioEngine on the simulator, not a mock.

Logs/results are under `build/plume11-logs/` and `build/Plume11/Logs/Test/`. UI screenshots are attached to the test results. Exports inspected during development are under `build/plume11-evidence/` (ignored build artifacts).

Xcode emits simulator audio-device/debugger diagnostics and an AVAudioSession warning about synchronous activation on the main thread. The app retains iOS 17 compatibility; simulator success does not certify responsiveness or hardware audio behaviour.

## Final local result and review gate

- Full simulator run before TestFlight archiving: **22 tests passed, zero failures** (18 model/audio/session-hosting, four UI). Log: `build/plume11-logs/testflight-final-tests.log`.
- Final fresh review: `/Users/jamesheffernan/.pi/agent/reviews/BreatheClock/2026-09-24-3.md` — no functional/spec findings; optional shared test-host fixture deferred.
- Generic iOS device build: **succeeded**, with signing disabled. This verifies device-SDK compilation, not installation, signing or on-device behaviour.
- `git diff --check` and Info.plist validation passed. James authorized commit, push and TestFlight delivery on 24 September; actual delivery status belongs in the TestFlight handoff, not the earlier local-build results.
- Fresh review: `/Users/jamesheffernan/.pi/agent/reviews/BreatheClock/2026-09-24-1.md`.
- **Approved completion-tone fix:** James approved the fix on 24 September. The completed-session interruption path now stops the remaining tone without changing the Complete screen. A regression test hosting the actual SessionView with real audio reproduced the failure before the fix and passed afterwards. Coverage also includes an audio-interruption notification during the tone; notifications are simulated, not physical headphone/call events. The full suite and unsigned device build both passed after the fix.
- Follow-up fresh review: `/Users/jamesheffernan/.pi/agent/reviews/BreatheClock/2026-09-24-2.md`. James approved addressing its notification-threading concern before TestFlight. Both views now explicitly deliver interruption/route notifications on `DispatchQueue.main`; the session's engine-configuration notification uses the same scheduler. Hosted-view tests post from background queues and assert cancellation publishes on the main thread. The initial background-route test already passed on this simulator before the explicit scheduler change, so this is defensive serialization, not a reproduced race. All five hosted interruption tests passed twice consecutively after the change.
- Optional sharing of interruption/route notification decoding remains unapplied: it was not part of the approved fix.
- Three other review findings concern supposedly missing Swift interpolation and shell continuation backslashes. The source contains those backslashes and the corresponding UI tests pass. A reproducible `zsh print` issue in the fresh-review packet builder stripped them before review; the harness bug is logged, not changed in this task.
- OmniFocus updated and read back: action `aNjYuI7OzCq` is now **Install the local Plume 1.1 build from Xcode and test it on my iPhone**, retaining its Computer tag and no dates. Its notes contain the Xcode project path, this checklist, test/build evidence and the unresolved notification-threading concern. The project remains open; the iPhone checks have not been performed.

## James's device check — required before release

Install the new **Plume 1.1.0 TestFlight build** once delivery is confirmed. James should not need Xcode. Check the version and timestamp build number against the delivery receipt; the older TestFlight/App Store build does not contain these changes. Record iPhone, iOS version, sound selection, routine and result for any failure.

- [ ] **About:** version 1.1.0, exact credit, and “Cambridge, UK”. Check normal and large text sizes, light/dark schemes.
- [ ] **Previews:** Bowl, Fork and Turf each play four tones with the right-side bars advancing together. Off stays silent. Rapidly switch sounds; choose Off; leave Settings; background the app. No delayed sound or stale animation should return. Check VoiceOver values and Reduce Motion.
- [ ] **First use:** the breathing primer stays silent until Begin. Countdown pips then match 3, 2, 1.
- [ ] **Locked finite session:** Box, 1 minute, each sound. Lock after countdown; hear every phase and one completion. Wait beyond the aligned 1:04 breath duration; no further cue. Unlock to Complete.
- [ ] **Continuous + infinite:** Coherence with sound. Lock and switch apps for several minutes. Return with audio/orb aligned. Pause silences immediately; Resume continues from that position; End stays silent. Repeat with an infinite non-continuous routine.
- [ ] **Guided + rapid routines:** Samadhi crosses stage boundaries on time while locked. Check Power Breath's rapid phases and holds (only if appropriate under the app's safety guidance).
- [ ] **Interruptions:** during a session and preview, receive a call and disconnect headphones/Bluetooth. No surprise speaker playback. Session remains paused after interruption; Resume works without jumping back or playing missed cues. Also disconnect headphones or receive a call during the completion tone: it must stop, with the Complete screen still showing. Try a new output route too.
- [ ] **Silent + haptics:** Audio Off pauses on lock/app switch, then waits for Resume. Verify foreground haptics still work; do not expect locked-screen haptics.
- [ ] **Other audio:** test alongside music/podcast. Confirm mixing, route changes, no silent-mode surprises, and other audio continues normally after Pause/End/completion.
- [ ] **Stress:** lock immediately after Begin; rapid Restart/Pause/End; repeat a long session. No stuck “Preparing”, delayed restart, overlapping sounds, growing memory or undue battery drain.

**Release gate:** real lock-screen playback, Bluetooth/calls, haptics, accessibility and long-duration battery/performance remain unverified until these checks pass. Simulator app switching is not proof of iPhone suspension behaviour or App Review acceptance. Stop release work for unwanted playback, failure to stop, timing drift or a route/interruption regression; keep the existing released build available. James owns this device pass before any release submission.

## Platform references consulted

- [AVAudioSession playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback): playback under screen lock; `UIBackgroundModes` audio for background operation; mixing options.
- [AVAudioPlayerNode buffer scheduling](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer(_:at:options:completioncallbacktype:completionhandler:)): actual played-buffer callbacks; stopping also invokes callbacks, hence generation guards.
- [Audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).
- [Audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).
