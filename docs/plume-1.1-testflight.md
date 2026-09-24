# Plume 1.1 TestFlight delivery — 24 September 2026

## Delivery

- App: **Plume Breathwork**, `com.turfterrace.plume.ios` (App Store Connect app `6786672870`).
- Version/build: **1.1.0 (202609241719)**.
- Source: `b5836c6748f8a79235576888cd8bc0e56ce6fa7f`, pushed to `codex/plume-release-recovery-20260826` with James's approval. The push also includes Codex's existing local signing-keychain fix `49aa7ff`.
- Archive job: https://github.com/jamespheffernan/Plume/actions/runs/36033447378 — succeeded.
- Apple package validation: **VERIFY SUCCEEDED with no errors**.
- Apple upload: **UPLOAD SUCCEEDED with no errors**, delivery `b81e58ef-ba00-491a-af2f-318ede00a592`.
- Apple processing: **COMPLETE**, zero errors and warnings; build **VALID**.
- Tester availability: **IN_BETA_TESTING**, auto-notification enabled. Read back the new build's relationship to the existing internal **jimmy** group and James's active/installed tester membership.
- Saved and read back the en-GB **What to Test** notes. No new public/external tester group or public App Store submission was created. Existing all-build-access internal groups retain their normal automatic access.

Open **TestFlight → Plume Breathwork → Update/Install** on the iPhone and select the version/build above. No Xcode is needed on James's part.

OmniFocus action `aNjYuI7OzCq` now reads **Open TestFlight on my iPhone and test Plume 1.1**, tagged **Phone**, with the exact build, download instructions and complete device checklist. Saved state was read back; no dates were added and the project remains open for device testing.

## Verification

- **22 tests passed:** model timing, real audio playback, session/Settings interruption handling, and four UI tests.
- The completion-tone interruption regression failed before its fix and passed afterwards. Both views explicitly deliver audio notifications on the main queue; tests cover background delivery for route/engine notifications and preview cancellation.
- Final fresh review: `/Users/jamesheffernan/.pi/agent/reviews/BreatheClock/2026-09-24-3.md` — no functional/spec findings. Optional test-host fixture cleanup deferred.
- Archive tuple checked before signing: Xcode `17F113` (26.6), SDK `iphoneos26.5` / `23F81a`, released macOS host `25G83`. The beta Mac did not compile the release archive.
- Local export/signing used Xcode 26.6 and the existing Turf Terrace distribution certificate/profile. Signed app verification passed; `get-task-allow=false`; application identifier is `7W38KL8969.com.turfterrace.plume.ios`.
- IPA SHA-256: `16a1670ff089736d79f7d69816081ea69cf3a56aa0af5147c9bed213d86abd56`.

Full physical-iPhone checklist: [Plume 1.1 validation](plume-1.1-validation.md). Lock-screen playback, actual headphone/call events, haptics, accessibility and battery performance still need that pass. TestFlight availability does not prove those behaviours or public App Review acceptance.

## Evidence and repeatable route

Local evidence directory: `/Users/jamesheffernan/GitHub/turfterrace-review/BreatheClock/build/testflight-20260924/` (ignored build artifacts).

- `archive-metadata.json`: embedded build and toolchain stamps.
- `export-validation.log`: signing/export and Apple's package validation.
- `upload.log`: transport receipt.
- `upload-processing.json`, `build-processing.json`: Apple processing responses.
- `build-access.json`, `testers-final.json`: verified internal build state, tester-group access and James's membership.
- `localizations-final.json`: read-back proof of What to Test notes.
- `signed-package/export/Plume.ipa`: exact validated and uploaded binary.
- `ipa-sha256.txt`: binary checksum.

The proven route is the existing `.github/workflows/release-archive.yml`: archive on released macOS 26 / Xcode 26.6; download that archive; verify with `scripts/verify_release_toolchain.sh`; sign/export/validate locally with `scripts/upload_testflight.sh` using `PLUME_PREBUILT_ARCHIVE_PATH` and `PLUME_SKIP_UPLOAD=1`; upload that exact IPA with `altool`; then verify processing and tester-group access through App Store Connect. Never rebuild on the beta host or treat transport success as TestFlight availability.

Apple's upload/internal-tester documentation and the current official App Store Connect OpenAPI specification were consulted for this delivery. Credentials were read from the existing local signing setup, not placed in the repository or GitHub.
