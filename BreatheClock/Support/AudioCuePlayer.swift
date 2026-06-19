import AVFoundation
import Foundation

final class AudioCuePlayer {
  static let shared = AudioCuePlayer()

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let sampleRate: Double = 44_100
  private let format: AVAudioFormat
  private var pendingPreviewWorkItems: [DispatchWorkItem] = []

  // Buffers are synthesized once and reused — synthesis is far too heavy to run
  // on the main thread at every breath boundary (it would stutter the orb).
  private let renderQueue = DispatchQueue(label: "breatheclock.audio.render", qos: .userInitiated)
  private let cacheLock = NSLock()
  private var bufferCache: [String: AVAudioPCMBuffer] = [:]
  private var cueGainCache: [String: Double] = [:]
  private var didConfigureSession = false
  private var sustaining = false

  /// Target peak (pre-output-gain) every cue is normalized to, so switching
  /// cues never lurches the volume. Output gain then sets the gentle final level.
  private let targetPeak: Double = 0.45
  private let completionPeak: Double = 0.5

  private init() {
    format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.5
  }

  // MARK: - Discrete cues (one chime per phase boundary)

  func play(
    _ cue: AudioCue,
    for phase: BreathPhase.Kind,
    phaseDuration: TimeInterval? = nil,
    style: CueStyle = .crisp
  ) {
    guard cue != .off, style.volumeScale > 0, !style.continuous else { return }
    guard let buffer = discreteBuffer(for: cue, phase: phase, phaseDuration: phaseDuration, volumeScale: style.volumeScale) else { return }
    schedule(buffer, loops: false)
  }

  /// A soft pip for a single countdown digit (3 · 2 · 1), pitched to the cue's
  /// calm note so it previews the timbre, and quieter than the breath cues so it
  /// reads as an anticipatory lead-in. Plays for every cue style except silence.
  func playCountdownTick(_ cue: AudioCue, style: CueStyle) {
    guard cue != .off, style.volumeScale > 0 else { return }
    guard let buffer = countdownBuffer(for: cue, volumeScale: style.volumeScale) else { return }
    schedule(buffer, loops: false)
  }

  /// Pre-render the buffers a session will need, off the main thread, so the
  /// first boundary doesn't pay synthesis cost mid-animation.
  func prepare(cue: AudioCue, style: CueStyle, phases: [BreathPhase], cycleDuration: TimeInterval) {
    guard cue != .off, style.volumeScale > 0 else { return }
    renderQueue.async { [weak self] in
      guard let self else { return }
      if style.continuous {
        _ = self.continuousBuffer(for: cue, phases: phases, cycleDuration: cycleDuration, volumeScale: style.volumeScale)
      } else {
        for kind in Set(phases.map(\.kind)) {
          let duration = phases.first { $0.kind == kind }?.seconds
          _ = self.discreteBuffer(for: cue, phase: kind, phaseDuration: duration, volumeScale: style.volumeScale)
        }
      }
      _ = self.completionBuffer(for: cue)
      _ = self.countdownBuffer(for: cue, volumeScale: style.volumeScale)
    }
  }

  // MARK: - Continuous cue (one seamless looping tone)

  func startContinuous(_ cue: AudioCue, phases: [BreathPhase], cycleDuration: TimeInterval, volumeScale: Double) {
    guard cue != .off, volumeScale > 0 else { return }
    stopSustained()
    guard let buffer = continuousBuffer(for: cue, phases: phases, cycleDuration: cycleDuration, volumeScale: volumeScale) else { return }
    startIfNeeded()
    player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
    if !player.isPlaying { player.play() }
    sustaining = true
  }

  func setSustainedPaused(_ paused: Bool) {
    guard sustaining else { return }
    if paused {
      player.pause()
    } else {
      startIfNeeded()
      player.play()
    }
  }

  func stopSustained() {
    guard sustaining else { return }
    player.stop()
    sustaining = false
  }

  // MARK: - Preview & completion

  func playBoxPreview(_ cue: AudioCue) {
    stopPreview()
    guard cue != .off else { return }

    let previewPhases: [BreathPhase.Kind] = [.inhale, .holdFull, .exhale, .holdEmpty]
    for (index, phase) in previewPhases.enumerated() {
      let item = DispatchWorkItem { [weak self] in
        self?.play(cue, for: phase, phaseDuration: 4)
      }
      pendingPreviewWorkItems.append(item)
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index * 4), execute: item)
    }
  }

  func playCompletion(_ cue: AudioCue) {
    stopPreview()
    stopSustained()
    guard cue != .off, let buffer = completionBuffer(for: cue) else { return }
    schedule(buffer, loops: false)
  }

  // MARK: - Scheduling

  private func schedule(_ buffer: AVAudioPCMBuffer, loops: Bool) {
    startIfNeeded()
    player.scheduleBuffer(buffer, at: nil, options: loops ? [.loops] : [], completionHandler: nil)
    if !player.isPlaying { player.play() }
  }

  private func stopPreview() {
    pendingPreviewWorkItems.forEach { $0.cancel() }
    pendingPreviewWorkItems.removeAll()
    player.stop()
    sustaining = false
  }

  private func startIfNeeded() {
    #if os(iOS)
    if !didConfigureSession {
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try? AVAudioSession.sharedInstance().setActive(true)
      didConfigureSession = true
    }
    #endif

    if !engine.isRunning {
      try? engine.start()
    }
  }

  // MARK: - Buffer construction (cached)

  private func cached(_ key: String, _ build: () -> AVAudioPCMBuffer?) -> AVAudioPCMBuffer? {
    cacheLock.lock()
    if let hit = bufferCache[key] {
      cacheLock.unlock()
      return hit
    }
    cacheLock.unlock()

    guard let buffer = build() else { return nil }
    cacheLock.lock()
    bufferCache[key] = buffer
    cacheLock.unlock()
    return buffer
  }

  private func discreteBuffer(
    for cue: AudioCue,
    phase: BreathPhase.Kind,
    phaseDuration: TimeInterval?,
    volumeScale: Double
  ) -> AVAudioPCMBuffer? {
    let key = "d-\(cue.rawValue)-\(phase)-\(Int(volumeScale * 100))"
    return cached(key) {
      let raw = discreteSamples(for: cue, phase: phase, phaseDuration: phaseDuration)
      let scaled = raw.map { $0 * cueGain(for: cue) * volumeScale }
      return pcmBuffer(scaled)
    }
  }

  private func continuousBuffer(
    for cue: AudioCue,
    phases: [BreathPhase],
    cycleDuration: TimeInterval,
    volumeScale: Double
  ) -> AVAudioPCMBuffer? {
    let key = "c-\(cue.rawValue)-\(Int(cycleDuration * 10))-\(Int(volumeScale * 100))"
    return cached(key) {
      let raw = continuousLoopSamples(for: cue, phases: phases, cycleDuration: cycleDuration)
      let gain = normalizationGain(for: raw, target: targetPeak)
      let scaled = raw.map { $0 * gain * volumeScale }
      return pcmBuffer(scaled)
    }
  }

  private func completionBuffer(for cue: AudioCue) -> AVAudioPCMBuffer? {
    cached("comp-\(cue.rawValue)") {
      let duration = completionDuration(for: cue)
      let frames = Int(duration * sampleRate)
      guard frames > 0 else { return nil }
      var raw = [Double](repeating: 0, count: frames)
      for frame in 0..<frames {
        raw[frame] = completionSample(for: cue, time: Double(frame) / sampleRate, duration: duration)
      }
      let gain = normalizationGain(for: raw, target: completionPeak)
      return pcmBuffer(raw.map { $0 * gain })
    }
  }

  private func countdownBuffer(for cue: AudioCue, volumeScale: Double) -> AVAudioPCMBuffer? {
    let key = "cd-\(cue.rawValue)-\(Int(volumeScale * 100))"
    return cached(key) {
      let duration = 0.5
      let frequency = self.frequency(for: cue, phase: .exhale)
      let frames = Int(duration * self.sampleRate)
      guard frames > 0 else { return nil }
      var raw = [Double](repeating: 0, count: frames)
      for frame in 0..<frames {
        raw[frame] = self.countdownSample(time: Double(frame) / self.sampleRate, frequency: frequency, duration: duration)
      }
      // A touch under the breath-cue level so the count leads in, not competes.
      let gain = self.normalizationGain(for: raw, target: self.targetPeak * 0.6)
      return self.pcmBuffer(raw.map { $0 * gain * volumeScale })
    }
  }

  /// One normalization gain per cue, derived from its loudest phase (inhale),
  /// applied to every phase so relative dynamics (softer holds) survive.
  private func cueGain(for cue: AudioCue) -> Double {
    let key = cue.rawValue
    cacheLock.lock()
    if let hit = cueGainCache[key] {
      cacheLock.unlock()
      return hit
    }
    cacheLock.unlock()

    let reference = discreteSamples(for: cue, phase: .inhale, phaseDuration: nil)
    let gain = normalizationGain(for: reference, target: targetPeak)
    cacheLock.lock()
    cueGainCache[key] = gain
    cacheLock.unlock()
    return gain
  }

  private func normalizationGain(for samples: [Double], target: Double) -> Double {
    let peak = samples.reduce(0.0) { Swift.max($0, abs($1)) }
    return peak > 0 ? target / peak : 1
  }

  private func pcmBuffer(_ samples: [Double]) -> AVAudioPCMBuffer? {
    let frames = AVAudioFrameCount(samples.count)
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
    buffer.frameLength = frames
    guard let channel = buffer.floatChannelData?[0] else { return nil }
    for index in samples.indices {
      channel[index] = Float(max(-1, min(1, samples[index])))
    }
    return buffer
  }

  // MARK: - Sample synthesis (raw, pre-gain)

  /// Raw chime samples for a phase. The decaying tail beyond audibility is not
  /// rendered (the envelope still uses the full duration, so timbre is intact).
  private func discreteSamples(
    for cue: AudioCue,
    phase: BreathPhase.Kind,
    phaseDuration: TimeInterval?
  ) -> [Double] {
    let profile = toneProfile(for: cue, phase: phase, phaseDuration: phaseDuration)
    let renderDuration = audibleDuration(for: cue, fullDuration: profile.duration)
    let frames = Int(renderDuration * sampleRate)
    guard frames > 0 else { return [] }

    var out = [Double](repeating: 0, count: frames)
    for frame in 0..<frames {
      let time = Double(frame) / sampleRate
      let value: Double
      switch cue {
      case .off: value = 0
      case .bowl: value = bowlSample(time: time, frequency: profile.frequency, duration: profile.duration)
      case .fork: value = forkSample(time: time, frequency: profile.frequency, duration: profile.duration)
      case .turf: value = turfWebSample(time: time, frequency: profile.frequency, duration: profile.duration)
      }
      out[frame] = value * profile.amplitudeScale
    }
    return out
  }

  /// One cycle of a phase-continuous gliding tone, folded at the seam so it
  /// loops with no click and no drop to silence between breaths.
  private func continuousLoopSamples(
    for cue: AudioCue,
    phases: [BreathPhase],
    cycleDuration: TimeInterval
  ) -> [Double] {
    let cycle = max(cycleDuration, 1.0)
    let length = Int(cycle * sampleRate)
    guard length > 0 else { return [] }
    let fade = min(Int(0.03 * sampleRate), length / 4)
    let total = length + fade

    let dt = 1.0 / sampleRate
    var accumulator = 0.0
    var raw = [Double](repeating: 0, count: total)
    for frame in 0..<total {
      let time = Double(frame) / sampleRate
      let cyclePosition = time.truncatingRemainder(dividingBy: cycle)
      let freq = glideFrequency(for: cue, phases: phases, at: cyclePosition)
      accumulator += 2 * .pi * freq * dt
      raw[frame] = sin(accumulator) * 0.82 + sin(accumulator * 2) * 0.12
    }

    // Fold the continuation past the loop point onto the head: when the buffer
    // loops, its end now flows seamlessly into its start.
    var out = Array(raw[0..<length])
    if fade > 0 {
      for index in 0..<fade {
        let weight = Double(index) / Double(fade)
        out[index] = out[index] * weight + raw[length + index] * (1 - weight)
      }
    }
    return out
  }

  /// Pitch at a position within the cycle, gliding within each phase between the
  /// inhale and exhale tones (matching the discrete cue's phase frequencies).
  private func glideFrequency(for cue: AudioCue, phases: [BreathPhase], at position: TimeInterval) -> Double {
    guard !phases.isEmpty else { return frequency(for: cue, phase: .inhale) }
    let inhaleFreq = frequency(for: cue, phase: .inhale)
    let exhaleFreq = frequency(for: cue, phase: .exhale)

    var cursor: TimeInterval = 0
    for phase in phases {
      let end = cursor + phase.seconds
      if position < end || phase == phases.last {
        let progress = min(max((position - cursor) / max(phase.seconds, 0.001), 0), 1)
        let eased = 0.5 - 0.5 * cos(Double.pi * progress)
        let startFreq: Double
        let endFreq: Double
        switch phase.kind {
        case .inhale: startFreq = exhaleFreq; endFreq = inhaleFreq
        case .exhale: startFreq = inhaleFreq; endFreq = exhaleFreq
        case .holdFull: startFreq = inhaleFreq; endFreq = inhaleFreq
        case .holdEmpty: startFreq = exhaleFreq; endFreq = exhaleFreq
        }
        return startFreq + (endFreq - startFreq) * eased
      }
      cursor = end
    }
    return exhaleFreq
  }

  /// How long a chime stays audible — beyond this the exponential tail is below
  /// hearing, so there's no point synthesizing it. Sustained cues are untrimmed.
  private func audibleDuration(for cue: AudioCue, fullDuration: Double) -> Double {
    let threshold = 0.004
    let decay: (attack: Double, rate: Double)?
    switch cue {
    case .bowl: decay = (0.08, 7.6)
    case .fork: decay = (0.005, 8.5)
    case .turf, .off: decay = nil
    }
    guard let decay else { return fullDuration }
    let normalized = log(1 / threshold) / decay.rate
    let audible = decay.attack + normalized * (fullDuration - decay.attack)
    return min(fullDuration, audible)
  }

  private func toneProfile(
    for cue: AudioCue,
    phase: BreathPhase.Kind,
    phaseDuration: TimeInterval?
  ) -> ToneProfile {
    let baseDuration = duration(for: cue)
    let isHold = phase.isHold

    if cue == .turf {
      return ToneProfile(
        frequency: frequency(for: cue, phase: phase),
        amplitudeScale: 1.0,
        duration: baseDuration
      )
    }

    let duration = baseDuration * (isHold ? 0.7 : 1.0)

    return ToneProfile(
      frequency: frequency(for: cue, phase: phase),
      amplitudeScale: isHold ? 0.6 : 1.0,
      duration: duration
    )
  }

  private func frequency(for cue: AudioCue, phase: BreathPhase.Kind) -> Double {
    switch cue {
    case .off:
      return 0
    case .bowl:
      switch phase {
      case .inhale: return 261.63
      case .holdFull: return 392.00
      case .exhale: return 196.00
      case .holdEmpty: return 155.56
      }
    case .fork:
      switch phase {
      case .inhale: return 440.00
      case .holdFull: return 659.25
      case .exhale: return 329.63
      case .holdEmpty: return 277.18
      }
    case .turf:
      switch phase {
      case .inhale: return 392.00
      case .holdFull: return 261.63
      case .exhale: return 220.00
      case .holdEmpty: return 261.63
      }
    }
  }

  private func duration(for cue: AudioCue) -> Double {
    switch cue {
    case .off:
      return 0.1
    case .bowl:
      return 4.7
    case .fork:
      return 1.5
    case .turf:
      return 0.18
    }
  }

  private func completionDuration(for cue: AudioCue) -> Double {
    switch cue {
    case .off:
      return 0.1
    case .bowl:
      return 5.4
    case .fork:
      return 2.2
    case .turf:
      return 0.58
    }
  }

  private func bowlSample(time: Double, frequency: Double, duration: Double) -> Double {
    let partials: [(multiplier: Double, amp: Double, detune: Double)] = [
      (1.00, 1.00, 0),
      (2.07, 0.45, 5),
      (3.13, 0.22, -3),
      (4.21, 0.10, 4),
      (5.40, 0.05, -6)
    ]

    var sample = 0.0
    for partial in partials {
      for side in [-1.0, 1.0] {
        let cents = partial.detune + side * 4
        let tuned = frequency * partial.multiplier * pow(2, cents / 1200)
        sample += sin(2 * .pi * tuned * time) * partial.amp * 0.5
      }
    }
    return sample * envelope(time: time, duration: duration, attack: 0.08, decay: 7.6) * 0.22
  }

  private func forkSample(time: Double, frequency: Double, duration: Double) -> Double {
    let fundamental = sin(2 * .pi * frequency * time)
    let harmonic = sin(2 * .pi * frequency * 2 * time) * 0.08
    return (fundamental + harmonic) * envelope(time: time, duration: duration, attack: 0.005, decay: 8.5) * 0.28
  }

  private func turfWebSample(time: Double, frequency: Double, duration: Double) -> Double {
    let triangle = 2 * abs(2 * ((frequency * time) - floor(frequency * time + 0.5))) - 1
    let attack = 0.03
    let startGain = 0.0001
    let peakGain = 0.08
    let gain: Double

    if time < attack {
      let progress = min(max(time / attack, 0), 1)
      gain = startGain * pow(peakGain / startGain, progress)
    } else {
      let progress = min(max((time - attack) / max(duration - attack, 0.001), 0), 1)
      gain = peakGain * pow(startGain / peakGain, progress)
    }

    return triangle * (gain / peakGain) * 0.12
  }

  private func completionSample(for cue: AudioCue, time: Double, duration: Double) -> Double {
    switch cue {
    case .off:
      return 0
    case .bowl:
      let root = bowlSample(time: time, frequency: 196.00, duration: duration)
      let fifth = time >= 0.18
        ? bowlSample(time: time - 0.18, frequency: 261.63, duration: max(duration - 0.18, 0.1)) * 0.58
        : 0
      let upper = time >= 0.36
        ? bowlSample(time: time - 0.36, frequency: 392.00, duration: max(duration - 0.36, 0.1)) * 0.34
        : 0
      return root + fifth + upper
    case .fork:
      let first = forkSample(time: time, frequency: 329.63, duration: duration)
      let second = time >= 0.44
        ? forkSample(time: time - 0.44, frequency: 440.00, duration: max(duration - 0.44, 0.1)) * 0.72
        : 0
      return (first + second) * 0.9
    case .turf:
      let first = turfCompletionPip(time: time, frequency: 392.00, duration: 0.2)
      let second = time >= 0.24
        ? turfCompletionPip(time: time - 0.24, frequency: 523.25, duration: 0.26) * 0.82
        : 0
      return first + second
    }
  }

  private func turfCompletionPip(time: Double, frequency: Double, duration: Double) -> Double {
    guard time <= duration else { return 0 }
    return turfWebSample(time: time, frequency: frequency, duration: duration) * 1.55
  }

  /// A gentle bell pip: fundamental plus a soft octave, shaped by a raised-cosine
  /// swell so it fades in and out with no click — calm, not a race-start beep.
  private func countdownSample(time: Double, frequency: Double, duration: Double) -> Double {
    let tone = sin(2 * .pi * frequency * time) + sin(2 * .pi * frequency * 2 * time) * 0.12
    let progress = min(max(time / duration, 0), 1)
    let bell = 0.5 - 0.5 * cos(2 * .pi * progress)
    return tone * bell
  }

  private func envelope(time: Double, duration: Double, attack: Double, decay: Double) -> Double {
    if time < attack {
      return max(0, time / attack)
    }
    let normalized = min(max((time - attack) / max(duration - attack, 0.001), 0), 1)
    return exp(-decay * normalized)
  }

}

private struct ToneProfile {
  let frequency: Double
  let amplitudeScale: Double
  let duration: Double
}
