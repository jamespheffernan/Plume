# Plume — Launch Animation: Conceptual Range

A breadth-first exploration of the app-open moment, before committing one direction to depth. Goal: a launch that feels **pure and beautiful** and **sets the stage** for a breathing session — the threshold between the noisy world and a calm practice.

Method: [interface-conceptual-range](https://www.interfacecraft.dev/library/conceptual-range). Eight designers diverged under distinct generative lenses; a critic flagged sibling-variants and missing premise families; a synthesis pass clustered 41 raw concepts into **11 structurally different families** and a direction matrix. This packet asks you to pick one (or two) to take into depth — it does not yet design the chosen one.

---

## The canvas

There is **no launch animation today**. Cold launch drops straight into the Library list on cream paper; first run shows a safety sheet. The app's soul is the **breath orb** — a 1pt ink vessel ring, a swelling blurred halo, a radial-gradient ink sphere that grows on the inhale and dissolves into the empty ring on the exhale, all driven by one raised-cosine breath wave (`0.5 − 0.5·cos(πt)`), nothing snapping, everything settling. The wordmark is Fraunces light italic on warm cream. Any launch must survive **every** open (no friction at #20), degrade for Reduce Motion, and hand off cleanly into the Library or the first-run safety sheet.

## The obvious first idea (set aside)

> A splash screen: the "Plume" wordmark fades up on cream paper, holds a beat, fades out, Library appears.

**Hidden assumption:** that the launch must be a *separate gate you wait behind*, and that the brand moment is the *wordmark* rather than the *breath*. Almost every strong direction below breaks one of those two assumptions — it either removes the gate or makes the breath, not the logo, the hero.

---

## The eleven directions

Each is a different *premise*, not a restyle. Hero = the single strongest concept in that family.

### 1. Free-First-Frame Continuity — *recommended* · hero: **The Standing Vessel**
**Premise:** the OS LaunchScreen storyboard *is* a pixel-exact Plume frame — the empty vessel ring on cream — so the free, instant static image is literally the first frame. The live app reproduces that same ring and takes one breath in it.
**Feel:** the ring you tapped is the ring you end up holding — no seam, no wait.
**Why it wins:** the expensive-feeling part (the ring appearing) is free and pre-rendered, so perceived latency is zero on every launch including #20. Reduce Motion is free — the static ring *is* the still frame.
**Risk:** pixel-exact match between a raster ring and a live SwiftUI stroke is fragile across device scales; drift reads as a flicker.

### 2. Delivery-on-the-Exhale (Inversion) — *runner-up* · hero: **The App Exhales You In**
**Premise:** invert construction. Instead of building *up* into the Library, an already-full orb **exhales**, and the Library is what the exhale leaves behind, settling as the sphere empties.
**Feel:** the app breathes out and you're already inside what the breath left behind.
**Strength:** content fades from frame one (no "wait to build"); reuses the orb's signature dissolve, doing double duty as a calm primer.
**Risk:** the Library "breathing out" collapses into a generic fade unless the rows feel *emitted by the orb*, not faded in from the screen edges.

### 3. Single-Breath Orb (Reuse the Hero) · hero: **Single Breath**
**Premise:** the exact session orb takes one breath-wave cycle as the whole launch — the launch *is* a breath, not a splash — then dissolves into the Library.
**Feel:** one real breath of the hero orb, then you're in.
**Strength:** maximum brand fidelity at near-zero new code; irreducibly pure.
**Risk:** so restrained it may read as "the app was slow to load"; the magic depends entirely on the easing being felt, not seen.

### 4. Already-Alive / No-Distinct-Launch · hero: **Already Breathing**
**Premise:** remove the launch screen entirely. The Library is already composed; only one small settling breath of the whole layout plays, so the app reads as *awake*, not *loading*.
**Feel:** you were never made to wait; the app was already breathing when you arrived.
**Strength:** maximum purity, zero friction, content hit-testable from frame one.
**Risk:** may read as no animation at all and disappoint anyone wanting a "moment."

### 5. Apothecary Diffusion / Smoke & Ink · hero: **Tincture**
**Premise:** replace the logo reveal with a physical material event — a drop of warm ink blooming in cream water — whose settling edge becomes the vessel ring.
**Feel:** breath made visible as a substance settling on the page.
**Strength:** the most literal reading of *plume = vapor*; the most differentiated, ownable visual when tuned.
**Risk:** highest craft fragility — Canvas smoke can look like a scribble, the bloom may not resolve to clean paper, blur can band on the cream gradient.

### 6. Letterpress / Newsprint Craft · hero: **The Page Draws Breath**
**Premise:** the launch is the act of *printing* the page. The real Library is present but the ink is "wet" — a faint bleed-halo on every glyph — and over one breath it dries crisp while the accent plate blooms and pulls back.
**Feel:** a freshly-pressed sheet settling before your eyes.
**Strength:** dead-on editorial/apothecary identity; the real Library is readable throughout; cheap.
**Risk:** blur on live scrollable type can read as "not loaded"; GPU cost on older devices.

### 7. Atmosphere / Circadian Light · hero: **The Page Warms**
**Premise:** animate only the *light* crossing the paper — a dawn glow warming the cream to its true daylight tone — revealing the already-present Library. Context-aware variants tint by hour or by time-since-last-session.
**Feel:** sunrise crosses the page and the Library is lit into view.
**Strength:** extremely pure (only light moves); the context variants make every launch different, defeating #20 fatigue.
**Risk:** a pre-dawn dim can flash dark and break the cream brand; without a focal point it can feel like nothing happened on a bright screen.

### 8. Wordmark-Written-on-a-Breath · hero: **Punctuation**
**Premise:** the launch forms the Fraunces wordmark on one breath — and the orb is its terminal/period, the tittle that descends to complete the mark and *is* the orb.
**Feel:** the name writes itself on a single breath; the orb is its punctuation.
**Strength:** most identity-forward; ties wordmark, orb, and feather into one continuous line; yields a permanent brand detail.
**Risk:** SwiftUI can't truly stroke a serif glyph, so draw-on risks looking like a wipe; changing the mark is a brand decision beyond the launch.

### 9. Held Emptiness / Withholding · hero: **The Held Note**
**Premise:** make the moment a *withholding*, not an addition — show only the empty exhaled vessel ring for a held beat, then let the Library resolve out of that emptiness.
**Feel:** a single intake of stillness before the room assembles around the ring.
**Strength:** ceremonial yet pure; the centered empty ring is unmistakably Plume.
**Risk:** closest of the pure concepts to a conventional loading splash; a daily-only ceremony adds state that can feel like a bug.

### 10. Settling Gesture / Damped Motion · hero: **Coming to Rest**
**Premise:** the launch is the *tail* of a gesture — a feather, plumb-line, or orb arriving already in motion and damping to stillness, confirmed by a haptic landing.
**Feel:** a feather touches down and the instant it stills, you're home.
**Strength:** the felt landing gives a clean endpoint, so it never drags; "coming to rest" maps directly to the practice threshold.
**Risk:** overshoot is the trap — any bounce betrays apothecary calm and reads springy.

### 11. Sound / Haptic-Led Threshold · hero: **First Breath**
**Premise:** make the primary channel non-visual — a slow haptic swell-and-release marks the threshold while the Library sits fully rendered and still. The breath is felt under the thumb; the screen does almost nothing.
**Feel:** the threshold is felt in the hand, not watched.
**Strength:** the most launch-#20-proof and Reduce-Motion-immune of all; never gates interaction.
**Risk:** subtlety risks "did something just buzz?"; collapses to nothing on muted/haptics-off devices; audio at cold launch can clip or intrude in a quiet room.

---

## The two strongest, in motion

### The Standing Vessel (recommended)

```
−∞→0.0s   OS shows the static LaunchScreen — empty vessel ring on cream — for free,
          the whole time the process loads (50ms or 900ms; the user just sees a calm ring).
0.0s      First live SwiftUI frame renders the SAME ring at the SAME center/size.
          The seam is invisible — you cannot tell when the image ends and the app begins.
0.0–1.3s  Ink sphere swells inside the ring on the breath wave, rest 0.30 → ~0.92, halo blooming.
1.3–2.6s  Sphere dissolves (fillOpacity→0) back into the empty ring on the same wave.
~2.4s     As the fill passes ~0.3, the Library 'Plume' and rows crossfade up around the ring,
          which slides/scales to its small resting place in the list.
2.6s      Fully in Library, ring at rest.
```

- **Cadence:** free instant ring always. After run #1 it shortens to a half-breath dissolve (~1.0s, `didSeeFirstBreath` flag). Tap anywhere to resolve in 0.25s on the same wave.
- **Reduce Motion:** the LaunchScreen ring is already the still frame — skip the breath, crossfade the Library in over 0.2s. No special case to design.
- **Why:** it is the only direction that satisfies *pure*, *beautiful*, *sets-the-stage*, **and** the hardest constraint (instant, every launch, #20) at once. Launch and session share one object and one easing curve.

### The App Exhales You In (runner-up)

```
0.0s      Cold launch — a full ink sphere at ~0.95 scale, centered on paper, halo at full swell. Else empty.
0.0–0.3s  Held top-of-breath pause — sphere still — signalling 'this is a breath, match me'.
0.3–1.6s  Exhale — scale 0.95→0.32, fillOpacity 1→0 on the breath wave; the Library rows
          fade up and rise ~12pt, staggered top-to-bottom ~30ms/row, emitted by the emptying sphere.
1.6–1.9s  The empty ring glides up and docks as the small mark beside 'Plume' in the header.
```

- **Cadence:** full ~1.9s on first run; drop the hold and shorten to ~1.3s after. Tappable to skip.
- **Reduce Motion:** render the final still — ring docked in the header, full Library present.
- **Why pick it instead:** if the LaunchScreen-to-SwiftUI pixel match proves too fragile, this keeps the exhale-arrival purity without depending on a seam, though it cannot claim zero perceived latency.

---

## Direction matrix

| # | Direction | Changed premise | Strength | Risk | Best when |
|---|-----------|-----------------|----------|------|-----------|
| 1 | **Free-First-Frame** (Standing Vessel) | LaunchScreen IS the ring; app breathes in it | Zero perceived latency every launch | Raster↔SwiftUI pixel match is fragile | Zero-latency-every-launch is top priority |
| 2 | **Exhale-Arrival** (Exhales You In) | Orb exhales; Library is what it leaves behind | Content fades from frame one; orb's own dissolve | Collapses to a generic fade if stagger too subtle | Launch literally is the orb's dissolve |
| 3 | **Single-Breath Orb** | One cycle of the real orb IS the launch | Max brand fidelity, near-zero new code | May read as a slow load | Launch = the same breath mechanic as session |
| 4 | **Already-Alive** | No separate launch; layout takes one breath | Purest, zero friction, nothing to skip | May read as no animation | Restraint over a memorable beat |
| 5 | **Smoke & Ink** (Tincture) | Ink-in-water event whose edge becomes the ring | Most literal to plume=vapor; ownable | Highest craft fragility | Real tuning time for a signature visual |
| 6 | **Letterpress** (Page Draws Breath) | The launch is printing/inking the page | Editorial brand; real Library readable | Blur on type reads as "not loaded" | Print identity is the priority |
| 7 | **Circadian Light** (Page Warms) | Only light moves over the paper | Very pure; can encode hour/state | Pre-dawn dim can flash dark | Ambient warmth that resists #20 fatigue |
| 8 | **Wordmark on a Breath** (Punctuation) | The name forms; the orb is its period | Most identity-forward | SwiftUI can't stroke a serif; alters the mark | The wordmark is the hero |
| 9 | **Held Emptiness** (Held Note) | A held beat of the empty ring | Ceremonial yet pure | Closest to a loading splash | A once-a-day ceremony |
| 10 | **Settling Gesture** (Coming to Rest) | The tail of a gesture damping to stillness | Felt haptic landing; clean endpoint | Overshoot betrays calm | Kinesthetic, haptic-confirmed arrival |
| 11 | **Haptic Threshold** (First Breath) | A felt/heard breath; screen does nothing | Most #20-proof and Reduce-Motion-immune | "Did something buzz?"; nil when muted | Durability and non-gating matter most |

---

## Recommendation

Take **#1 Free-First-Frame Continuity (The Standing Vessel)** into depth, with **#2 Exhale-Arrival** as the fallback if the pixel-seam proves unwinnable.

It is the rare direction that is pure *and* beautiful *and* a true threshold *and* survivable at launch #20. The whole visible event is one breath of the empty vessel ring on cream — the literal soul of the app — with no new visual vocabulary to dilute the identity. Because the OS renders the ring for free, there is never a wait, and the breath shortens after the first run and is always skippable. Reduce Motion degrades to the static ring for free.

**To resolve before going deep:**

1. **The load-bearing risk** — can the LaunchScreen ring be made pixel-exact against the live SwiftUI `Circle().stroke` across all device scales (stroke width, antialiasing, color profile, safe-area-relative center)? Prototype the seam on the smallest and largest devices *first*. If a 1–2pt drift is perceptible, fall back to #2.
2. **Paper color at first paint** — the static LaunchScreen can't read the `@AppStorage` scheme. Launch on the default cream universally, or accept a paper-tint settle? (The ring's 0.4 opacity is forgiving; the paper is not.)
3. **Fast paths** — confirm `BC_DIRECT_SESSION` skips the breath entirely so it never delays practice; store `didSeeFirstBreath` / `launchCount` for the post-first-run shortening.
4. **First-run handoff** — sequence the safety `fullScreenCover` so the breath resolves *into* the disclaimer rather than fighting it.

---

## Items to review

Pick the direction (or two) to take into depth via `interface-conceptual-depth`. The recommendation is first.

- [ ] **#1 Free-First-Frame / The Standing Vessel** — recommended; the ring you tap is the ring you hold
- [ ] **#2 Exhale-Arrival / The App Exhales You In** — runner-up; the orb exhales the Library into being
- [ ] **#3 Single-Breath Orb** — the most literal "the launch is a breath," near-zero new code
- [ ] **#4 Already-Alive** — the purist's choice: no launch at all, just a settling breath
- [ ] **#5 Smoke & Ink / Tincture** — the most differentiated, most fragile signature visual
- [ ] **#6 Letterpress / The Page Draws Breath** — the editorial brand made material
- [ ] **#7 Circadian Light / The Page Warms** — light over paper; can encode hour/state
- [ ] **#8 Wordmark on a Breath / Punctuation** — the orb as the wordmark's period
- [ ] **#9 Held Emptiness / The Held Note** — a held beat of the empty ring
- [ ] **#10 Settling Gesture / Coming to Rest** — a feather damping to a haptic landing
- [ ] **#11 Haptic Threshold / First Breath** — felt in the hand, not watched
- [ ] **Other / combine two** — note which, and I'll reconcile them in depth
