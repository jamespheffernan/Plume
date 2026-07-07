# Plume — App Store Submission Review

**Date:** 2026-07-06
**Reviewer:** Claude (pre-submission audit)
**Build state verified:** Release build compiles clean under Xcode 27 beta 2 (27A5209h); signing pipeline present and wired.

## Verdict

The app itself is in good shape. It builds, it signs, and the code carries no App Store landmines — no privacy-sensitive APIs, no tracking, no network calls, no third-party SDKs. The remaining work is mostly App Store Connect paperwork plus two small compliance items and some config hygiene. Nothing here is a heavy lift.

The gating question is not "will it build" — it does. It is "is the store listing complete and are the two compliance risks handled."

---

## Must do — submission blocks without these

These are App Store Connect requirements. You cannot submit until they exist.

1. **Store listing metadata.** Screenshots (6.9"/6.7" iPhone set), name, subtitle, description, keywords, promotional text. Plume is iPhone-only and portrait-only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are needed.
2. **Support URL.** Required field. A single page with a contact email satisfies it.
3. **Privacy Policy URL.** Required for every app, even one that collects nothing. Host a short policy stating the app collects and transmits no data.
4. **App Privacy "nutrition label."** Answer the data-collection questionnaire as **Data Not Collected** — accurate here, since all state lives in on-device `UserDefaults` and nothing leaves the phone.
5. **Category and age rating.** Health & Fitness fits. The age questionnaire will land at 4+; the breath-hold techniques are covered by in-app disclaimers, not rating flags.

## Should do — avoids Apple warnings or rejection

6. **Add a privacy manifest (`PrivacyInfo.xcprivacy`).** The app reads and writes `UserDefaults` via `@AppStorage`, a "required-reason API." Ship a manifest declaring category `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`, `NSPrivacyTracking = false`, and empty collected-data and tracking-domain arrays. Without it Apple sends an ITMS-91053 "missing API declaration" notice on upload, and enforcement tightens every cycle. Low effort, closes the risk.

7. **"Wim Hof" is a trademarked name.** The routine `wim-hof` is titled "Wim Hof" and its source cites "The Wim Hof Method." Guideline 5.2.1 lets Apple reject apps that use a third-party brand without authorization. The technique is well disclaimed, but the *name* is the exposure. Safest: rename to a generic label (e.g. "Power Breath," "Cyclic Hyperventilation") while keeping the descriptive source note. Moderate risk — some apps pass with the name, some get flagged.

## Cleanup — not blocking, do it anyway

8. **Delete the dead alternate-icon names.** Both `project.yml:28` and the pbxproj Release/Debug configs list five alternates — `SageAppIcon IndigoAppIcon PlumAppIcon OchreAppIcon SlateAppIcon` — but only Sage and Indigo exist, and only three color schemes ship (`Theme.swift`). `actool` tolerates the missing three (verified: build succeeds), but the config lies about reality and is a latent validation risk. Reduce the list to `SageAppIcon IndigoAppIcon` in `project.yml`, then regenerate or hand-edit the pbxproj to match.

9. **Version string is hardcoded.** `SettingsView.swift:107` prints `"1.0.0"` as a literal. It will drift from `MARKETING_VERSION` on the next bump. Read `CFBundleShortVersionString` from the bundle instead.

10. **Commit the working tree before archiving.** `project.yml`, `Info.plist`, `project.pbxproj`, and `SessionView.swift` are modified but uncommitted — including the account migration from `com.jamesheffernan` / team `3MVGA7QVHM` to `com.turfterrace.plume.ios` / team `7W38KL8969`. The upload script archives from the working tree, so it will build, but commit first so the shipped binary maps to a known commit.

## Verify — I could not fully confirm these

11. **Variable-font weights render distinctly.** `Theme.swift` requests PostScript names `Fraunces-Bold`, `Fraunces-Light`, `Manrope-SemiBold`, etc., but the bundle ships single variable files (`Fraunces-Variable.ttf`, `Manrope-Variable.ttf`). iOS does not always expose every named instance of a variable font by PostScript name; missing ones silently fall back to the default weight. Look across Library, Session, and Settings and confirm the weight contrast is real, not a uniform fallback. Cosmetic, not a blocker.

12. **Dry-run the archive and validate.** Before the real upload, run `PLUME_SKIP_UPLOAD=1 scripts/upload_testflight.sh` to produce the IPA, then validate it (Xcode Organizer → Validate App, or `altool --validate-app`). Validation surfaces asset and entitlement warnings the compile step does not.

---

## Already solid — leave alone

- **Build and signing.** Release compiles clean. Distribution cert (`iPhone Distribution: Turf Terrace Ltd`), App Store provisioning profile, and App Store Connect API key are all wired into `scripts/upload_testflight.sh`. Installed Xcode (27A5209h) is on the script's accepted-for-upload list.
- **Export compliance.** `ITSAppUsesNonExemptEncryption = false` is set, so no per-upload encryption prompt.
- **Launch screen and icons.** `UILaunchScreen` color is set; all three shipping icons are present at 1024×1024.
- **Safety and health framing.** The app gates first launch behind a safety acknowledgement, carries per-technique contraindications and intensity warnings, states plainly it is "not medical advice," and cites an established source for every routine. This is exactly what defuses Guideline 1.4.1 (physical harm) review.
- **Privacy surface.** No camera, microphone, location, HealthKit, notifications, or network. No analytics. No third-party SDKs. Nothing needs a usage-description string.
- **Debug hooks are safe.** `BC_DIRECT_ROUTE` / `BC_DIRECT_SESSION` are read from environment variables set only by the test harness; they are absent from the scheme, so they cannot activate in a shipped build.

---

## Items to review

- [x] Rename the "Wim Hof" routine to avoid the trademark → renamed to **Power Breath** (commit `73cdb54`)
- [x] Add `PrivacyInfo.xcprivacy` for the `UserDefaults` required-reason API (commit `006a3ad`)
- [x] Trim the alternate-icon list to the two icons that exist (commit `9ab59ca`)
- [ ] Confirm the privacy policy will state "no data collected" and host it — **yours to do (App Store Connect)**
- [x] Run the archive + validate dry-run before the real upload — run with `PLUME_SKIP_UPLOAD=1`

## Closeout status (loop, 2026-07-07)

Every in-repo item is committed on `session-feel-polish`, each Codex-reviewed (gpt-5.5, xhigh) and build-verified before commit:

| Commit | Item |
| --- | --- |
| `97a5443` | Baseline: account/bundle-id migration, `ITSAppUsesNonExemptEncryption`, `import Combine` (item #10) |
| `006a3ad` | Privacy manifest — UserDefaults required-reason (item #6) |
| `9ab59ca` | Alternate-icon list trimmed to reality (item #8) |
| `ad5c9f9` | Settings version read from bundle (item #9) |
| `73cdb54` | "Wim Hof" → "Power Breath" (item #7) |

**Still yours (can't be closed from the repo):** the App Store Connect listing — screenshots, support URL, privacy-policy URL, category, age rating, and the "Data Not Collected" privacy label (must-do items #1–5). Optional: eyeball the variable-font weights (item #11).
