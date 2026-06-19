# Next-version feedback (in-progress)

Captured during a feedback pass. **Not yet implemented** — tracking only.

## 1. Sound for the start countdown
**Request:** There should be a sound for the breath clock start countdown.

**Current state:** A countdown pip already exists — `SessionView.triggerIntroCue()` calls
`AudioCuePlayer.playCountdownTick(...)` on each digit (3·2·1), a soft bell pip pitched to
the selected cue. It re-fires after Restart too.

**Why it may be inaudible / feel missing:**
- Silent when the audio cue is set to **Off**.
- Silent for any routine whose `outcomeFamily.cueStyle == .silent` (volumeScale 0).
- Quieter than breath cues by design (`targetPeak * 0.6`) — possibly too subtle.

**Open question for implementation:** Should the countdown tick always play (even with cue Off
/ silent family), or just be made louder/clearer for cues that already use it?
