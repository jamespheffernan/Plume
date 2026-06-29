# Plume Interface Craft Transition Review

Rich HTML artifact: [plume-interface-craft-transition-review.html](./plume-interface-craft-transition-review.html)

This review packet covers two session-surface aspects:

- The orb transition around inhale, hold, and exhale.
- The count, label, audio, haptic, and accessibility feedback around that same boundary.

Four read-only sub-agent passes informed it: conceptual range and conceptual depth for each aspect.

## Recommendation

Prototype the current vessel/ring/dissolve concept first. At full inhale, fill the circle to the ring. Then split scale, fill, halo, ring, digit, and label timing so the boundary reads as a designed handoff instead of a shared `raw` value crossing a threshold.

Keep Trace Memory as the richer second prototype. Keep Liquid Meniscus as the replacement concept only if the refined vessel still feels too abstract.

## Items to review

- [ ] **Prototype 1: Decoupled vessel.** Keep the current orb premise. Make full inhale fill the circle to the ring. Add per-boundary timing windows, smoothstep fill thresholds, halo lag, subtle ring catches, delayed labels, and richer accessibility values.
- [ ] **Prototype 2: Trace Memory.** Add a faint previous-state afterimage around full and empty holds so the boundary gains continuity without new visible instruction copy.
- [ ] **Prototype 3: Liquid Meniscus.** Test only if the refined vessel still fails. It changes the premise from a scaling orb to breath volume inside a vessel.
- [ ] **Feedback rule.** Keep one visible phase label. Do not show "Next: Exhale" or similar copy during the session.
- [ ] **Full-fill rule.** Treat a fully filled circle as the non-negotiable top of inhale. The full state should not read as a smaller disc inside a ring.
- [ ] **Accessibility rule.** Keep the screen quiet, but let VoiceOver add next-phase context when two seconds or less remain.
- [ ] **Discard list.** Do not prototype a visible progress ring, a final-second tick, fill-before-motion, or a zero digit first.

## Source surfaces

- `BreatheClock/Views/SessionView.swift`
- `BreatheClock/Models/BreathingModels.swift`
- `docs/session-feel-polish-plan.md`
