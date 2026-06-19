# Plume — session-feel polish plan

From feedback notes (2026-06-19). Concise; tracking the v-next pass.

## Decisions (from review)

- **Rebirthing:** keep, but cite it. Add a source/origin line to *every* routine.
- **Train:** remove all three (Light Breathing, Kumbhaka, BOLT Score) and the Train category + goal.
- **Plume identity:** new plume icon/logo; keep the in-session breathing orb a circle.
- **Colour:** cut six schemes to three, more distinct, calm, traveler's-notebook feel.

---

## Items to review

- [ ] **1. One screen + category pills.** Collapse the two-layer menu (Goals → Library) into a single browse screen. One horizontal row of small pills at the top: `All · Calm · Focus · Inward · Energize · Release` (Train gone). `All` selected by default shows the full grouped list; tapping a pill filters to that category. Row scrolls horizontally if it overflows. Delete `GoalEntryView`, the `.goal` route, `focusedCategory`, and the `startOnGoals` setting.

- [ ] **2. Remove the "eased" pace.** Delete `BreathPace`, `Routine.reducedPhases`, `resolved(for:)`, `hasReducedVariant`, and the "Pace" selector in `SetupView`. Routines launch at their full pattern only. Fold any genuinely useful "shorten if it strains" guidance into the description, not a toggle.

- [ ] **3. Cut the warnings way down.** Today there are six warning surfaces. After:
  - First-launch disclaimer: keep, trimmed to ~2 sentences. Drop the 5-item contraindication list from the launch screen.
  - In-session "Stay seated · stop if you feel faint" banner: **remove**.
  - Per-routine `safetyNote`: keep only for the genuinely intense ones (Wim Hof, Rebirthing, Energy). Drop from Sleep/Box/etc.
  - Intense pre-session gate: keep for Wim Hof + Rebirthing but as **one** concise screen — and merge Rebirthing's separate "grounding intro" into it (no double warning).
  - Settings → Safety: keep, trimmed.

- [ ] **4. First-run breath primer.** The first time a session starts, show a short one-time animation demoing the orb: grow = *Inhale*, steady = *Hold*, shrink = *Exhale*, with rotating captions, then "Begin." Gated on `@AppStorage("didSeeBreathPrimer")`; skippable. Runs before the 3·2·1 countdown.

- [ ] **5. Fix the hold-out → inhale transition.** Today the orb fills in *then* starts growing (dead zone below `dissolveTop`). Change `pupilStage` so on inhale the orb **grows from the rest size immediately and the fill rushes in at the same time**, with the fill-in faster than the previous fill-out (asymmetric threshold by phase: inhale fills by ~10% of the breath, exhale empties over ~20%). Keep the empty-ring-at-bottom look.

- [ ] **6. Session control bar redesign.** The Restart / Pause / End text buttons read as an afterthought. Proposal: primary **Pause/Resume** becomes a solid ink capsule; **Restart** and **End** become quiet bordered "ghost" capsules either side. Same treatment on the completion screen. (Open to alternatives — see mock.)

- [ ] **7. Remove Hum + Wood sounds.** Delete `.hum` and `.wood` from `AudioCue` and their ~10 branches in `AudioCuePlayer`. Remaining cues: Off · Bowl · Fork · Turf. (Bhramari's on-screen "Hum" guidance label is unrelated and stays.)

- [ ] **8. Remove the Train category.** Delete the three routines, the `Train` goal/category, and the `.train` outcome-family plumbing.

- [ ] **9. Three colour schemes.** Reduce to three well-separated, calm, traveler's-notebook palettes; remove Plum / Ochre / Slate (enum + icon sets):
  - **Newsprint** — warm cream paper, near-black warm ink, terracotta accent (the neutral/default).
  - **Sage** — cream paper, deep forest-green ink, muted ochre accent (earthy).
  - **Evening** — dimmer warm paper, deep indigo ink, warm brass accent (cool/dark).

- [ ] **10. Plume logo / app icon.** Redesign the app icon + wordmark as a single calm plume (feather) mark in ink on paper. Generate the three scheme icon variants (Newsprint/Sage/Evening) at required sizes; remove the dropped icon sets. Breathing orb stays a circle.

- [ ] **11. Routine citations.** Add `source: String?` to `Routine` and show a small muted origin line on the Setup screen (and/or a "Sources" list in Settings). Attributions:
  - Sleep → 4-7-8, popularized by Dr. Andrew Weil.
  - Physiological Sigh → cyclic sighing, Stanford (Balban et al., 2023) / Huberman.
  - Coherence → resonance / coherent breathing (~6 bpm); Lehrer & Gevirtz.
  - Box / Box 5 → box / tactical breathing (military training).
  - Bhramari → bee-breath pranayama (traditional yoga).
  - Alternate Nostril → nadi shodhana (traditional yoga).
  - Wim Hof → the Wim Hof Method.
  - **Rebirthing → conscious connected breathing, developed by Leonard Orr (1970s).**
  - Calm / Energy / Samadhi → short technique-origin notes.

---

## Sequencing

1. Content/model: routines (Train out, citations in, eased out), `AudioCue` (hum/wood out). 
2. Theme: three schemes.
3. Navigation: pills screen, delete GoalEntry/startOnGoals.
4. Session: transition fix, control bar, first-run primer, warning trims.
5. Icons/logo: plume art for three schemes.
6. Build + simulator smoke test each phase.

## Verification

- `xcodebuild` for the simulator after each phase; launch in simulator and click through: pills filter → setup → primer (first run) → session orb transitions → completion.

## Open questions

1. Control-bar redesign (#6) — OK with the solid-primary + ghost-capsule direction, or prefer icons?
2. Citations (#11) — surface on the Setup screen, a Settings "Sources" list, or both?
3. Pill label for Contemplative — "Inward" (matches the old goal copy) or keep "Contemplative"?
