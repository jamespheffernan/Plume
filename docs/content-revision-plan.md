# Breathe Clock — Content Revision Plan

Bring the app's content (routines, names, descriptions, safety, framing, sensory mapping) in line with `breathwork-expert-capsule.md` and best practice.

Tags: **[data]** = edit `BreathingModels.swift` only · **[model]** = needs a model/structure change · **[ui]** = needs view work · **[decision]** = needs your call.

Reference files: [BreathingModels.swift](../BreatheClock/Models/BreathingModels.swift) · [SessionView.swift](../BreatheClock/Views/SessionView.swift) · [SetupView.swift](../BreatheClock/Views/SetupView.swift) · [SettingsView.swift](../BreatheClock/Views/SettingsView.swift) · [AudioCuePlayer.swift](../BreatheClock/Support/AudioCuePlayer.swift)

---

## Routine-by-routine verdicts

| # | Routine | Current pattern | Verdict | Action |
|---|---------|-----------------|---------|--------|
| 1 | Coherence | 5.5 / 5.5 | ✅ Keep | Reference-accurate. Refresh copy only. |
| 2 | Calm | 4 / 8 | ✅ Keep | Good 1:2 downshift. Add nasal/unforced cue. |
| 3 | Focus | 4-4-4-4 | ⚠️ Dedupe | Identical to Box. Merge into Box family. **[decision]** |
| 4 | Sleep (4-7-8) | 4 / 7 / 8 | 🔧 Keep + soften | Add reduced-ratio variant + hold caution. Surface "4-7-8". |
| 5 | Energy | 3 / 3 | 🔧 Reframe | Frame as gentle up-regulation; active-inhale cue + light-headed caution. |
| 6 | Physiological Sigh | 2 + 1 / 8 | ✅ Keep | Exemplary. Copy refresh only. |
| 7 | Box | 4-4-4-4 | 🔧 Keep + soften | Canonical box. Add reduced (3-3-3-3 / drop holds). |
| 8 | Box 5 | 5-5-5-5 | 🔧 Keep | Fold in as a "level" of Box (progression). |
| 9 | Kumbhaka | 2 / 4 / 2(empty) | 🔧 Reframe | "Kumbhaka" = generic retention. Reframe as CO2/extended-exhale; air-hunger caution. **[decision]** |
| 10 | Tummo (Wim Hof) | 1.5 / 1.5 | ❌ Misrepresented | No retention rounds = not Wim Hof. Build round structure + strong safety. **[model][decision]** |
| 11 | Tesla Breath | 3 / 6 / 9 | 🔧 Rename | Drop mysticism; honest "3-6-9 retention" + hold caution. **[decision]** |
| 12 | Sri Yantra | 6 / 3 / 6 | 🔧 Rename / cut | Mild hold pattern w/ mystical name. Honest rename or remove. **[decision]** |
| 13 | Aura | 8 / 8 "humming" | ❌ Misrepresented | No humming. Implement Bhramari hum cue + rename, or remove. **[model][decision]** |
| 14 | Root2 | 5 / 7.071 | 🔧 Reframe / cut | Extended-exhale w/ math gimmick. Fold into Calm family or remove. **[decision]** |
| 15 | Detox | 4 / 4 / 2 | ❌ False framing | "Detox" is pseudoscience; short exhale = activating, not calming. Rename honestly or remove. **[decision]** |
| 16 | Asthma Relief | 2 / 3 / 3(empty) | ❌ Medical claim | Drop condition name; reframe as Buteyko-style light breathing, comfort-based holds. **[decision]** |
| 17 | Rebirthing | 2 / 2 continuous | 🔧 Add safety | Somatic release: needs intensity warning + grounding intro/outro. **[ui]** |
| 18 | Alternate Nostril | box ×2 | ❌ Misrepresented | No left/right nostril guidance = not the practice. Add side cues. **[model][ui]** |
| 19 | Vortex | Fibonacci ladder | 🔧 Reframe / cut | 13s inhale + 13s empty-hold, novelty. Honest reframe + caution, or remove. **[decision]** |
| 20 | Samadhi | (empty) | ❌ Dead end | `phases: []` → "No timed cycle yet". Give real guided content or remove. **[decision]** |

Accurate keepers: Coherence, Calm, Physiological Sigh, Sleep, Box/Box 5.

---

## Cross-cutting workstreams

### A. Safety scaffolding (capsule's whole "Safety and Accessibility" section — currently absent)
- **A1** App-level disclaimer + contraindications (pregnancy, cardiovascular, hypertension, seizure, respiratory illness, acute trauma). About screen + first-run. **[data][ui]**
- **A2** Per-routine caution notes on Setup screen (new `safetyNote` field). **[model][ui]**
- **A3** Hard rules for intense practices: "Never in water, while driving, or standing unsupported." Acknowledgement gate before Tummo/Rebirthing. **[model][ui]**
- **A4** In-session "stop if faint / chest pain / distress" affordance. **[ui]**

### B. Fix misrepresented techniques (accuracy)
- **B1** Wim Hof / Tummo round structure: breathe cycles → exhale retention → recovery inhale-hold, repeated N rounds. Needs multi-stage session model. **[model]**
- **B2** Alternate Nostril: left/right nostril guidance (visual + label). Needs `nostrilSide` on phase. **[model][ui]**
- **B3** Aura → Bhramari: humming-exhale cue (visual prompt + wire the existing `hum` audio), rename. **[model][ui]**
- **B4** Samadhi: real guided/untimed progression content, or remove. **[decision]**

### C. Honest naming & descriptions (pure content)
- **C1** Remove medical claim: "Asthma Relief" → Buteyko-style "Light Breathing". **[data][decision]**
- **C2** Reframe mystical/novelty names: Tesla, Sri Yantra, Root2, Detox, Vortex — rename + honest copy, or remove. **[data][decision]**
- **C3** Rewrite every description in capsule style: pattern + primary effect + one key cue (nasal vs mouth, active vs passive). **[data]**
- **C4** Resolve Focus/Box duplication. **[data][decision]**

### D. Adjustability / reduced ratios (capsule repeats: "comfort beats compliance")
- **D1** Reduced-ratio variant or beginner/standard scaling for hold-heavy routines (4-7-8, Box, Tesla, Vortex). **[model][ui]**
- **D2** "Shorten / skip holds" option. **[model][ui]**

### E. Goal-first information architecture (capsule rule #1: "start from the state goal")
- **E1** Recategorize into outcome families: Down-regulate · Coherence/Focus · Up-regulate · Somatic release · Respiratory training · Contemplative. **[data]**
- **E2** (Optional) goal-based entry screen: Calm / Sleep / Focus / Energy / Release / Train. **[ui]**

### F. Sensory matching by outcome family (capsule "Sensory Guidance")
- **F1** Per-routine default audio + cue intensity matched to family (calm = soft/sparse; energy = clearer count; assessment = silent). **[model]**
- **F2** Grounding intro/outro for somatic-release routines. **[ui]**
- **F3** (Optional) continuous glide tone for Coherence vs discrete chimes. **[audio]**

### G. Missing capsule families (optional / phase 2)
- **G1** Respiratory assessment: BOLT / Control Pause timer + instructions. **[feature]**
- **G2** Beginner→advanced progression scaffolding. **[feature]**

### H. Enabling data-model changes (umbrella for B/D/F)
- **H1** Extend `BreathPhase`: `route` (nasal/mouth), `action` (passive/active/forceful), `nostrilSide`, `humming`. **[model]**
- **H2** Extend `Routine`: `outcomeFamily`, `intensity`, `safetyNote`, `contraindications`, `defaultAudio`, `reducedVariant`, `guidanceText`. **[model]**
- **H3** Multi-stage/round session model (Wim Hof, somatic arcs). **[model]**

---

## Suggested sequencing
1. **Phase 1 — pure content, highest integrity, no model risk:** C1, C2, C3, C4, E1, A1. (Honest names/descriptions, medical-claim removal, goal-first categories, disclaimer.)
2. **Phase 2 — safety + adjustability:** A2, A3, A4, D1, D2, F1.
3. **Phase 3 — model-dependent accuracy fixes:** H1/H2, B2, B3, F2, then H3/B1 (Wim Hof rounds).
4. **Phase 4 — optional new families:** B4/Samadhi, G1 (assessment), G2 (progression), E2, F3.

## Decisions (locked)
- **Model growth: YES.** Extend `Routine`/`BreathPhase` + add a round/session structure to represent techniques accurately.
- **Removed (6):** Tesla, Sri Yantra, Root2, Detox, Vortex (mystical/novelty/ungrounded), and Samadhi (empty dead-end). *Samadhi can return later as a real guided/progression practice.*
- **Merged:** Focus → Box family (was an exact 4-4-4-4 duplicate).
- **Renamed/reframed:** Asthma Relief → "Light Breathing" (Buteyko, no medical claim); Aura → "Bhramari" (real humming); Tummo (Wim Hof) → "Wim Hof".
- **New roster: 13 routines** across 6 goal-first categories (Calm · Focus · Train · Contemplative · Energize · Release).

## Progress
- ✅ **Phase 1 content pass** (C1, C2, C3, C4, E1): roster cut, Focus merged, renames, all descriptions rewritten in capsule voice, goal-first categories.
- ✅ **Model extension** (H1/H2): `BreathPhase` gains route/action/nostrilSide/humming; `Routine` gains intensity/safetyNote/patternOverride + a clean explicit init; new enums (BreathRoute, PhaseAction, NostrilSide, Intensity) and `BreatheSafety` copy.
- ✅ **Safety scaffolding** (A1–A4): first-run acknowledgement (RootView) + Settings "Safety" section (disclaimer + contraindications); per-routine caution on Setup; acknowledgement gate before intense routines; always-visible "stop if faint" line in-session for non-gentle.
- ✅ **Accuracy fixes** (B1/B2/B3): Wim Hof now runs real rounds (30 brisk breaths → 45s exhale hold → recovery inhale + 15s hold, repeated; flagged intense); Alternate Nostril shows L/R side per phase (simplified to authentic no-hold Nadi Shodhana); Bhramari cues "Hum" on a lengthened humming exhale.
- ✅ Full simulator build passes (`xcodebuild … BUILD SUCCEEDED`).
- ✅ Visually verified on iPhone 17 simulator: onboarding, goal-first library, per-routine caution (Sleep/Energy), intensity gate (Wim Hof), Wim Hof rounds + in-session caution, Bhramari "HUM" cue, Alternate Nostril "INHALE · LEFT" cue, Settings safety section.

### Known simplifications (candidates for follow-up)
- **Wim Hof retention is a fixed 45s**, not open-ended "hold as long as comfortable" — the session engine has no tap-to-advance. A dedicated rounds UI with an open-ended hold would be more faithful.
- **Wim Hof duration picker maps to round count** via cycle alignment (e.g. "3 min" → 2 rounds ≈ 5 min); the Setup "Completes at …" line discloses it, but a rounds-based picker would read better.

## Remaining (not yet started)
- ⬜ **D** — reduced-ratio / beginner scaling for hold-heavy routines.
- ⬜ **F** — sensory cues matched to outcome family; grounding intro/outro for Rebirthing; optional continuous glide tone for Coherence.
- ⬜ **G** — respiratory assessment (BOLT / Control Pause), progression scaffolding (could revive Samadhi as a guided practice).
- ⬜ **E2** — optional goal-based entry screen.
