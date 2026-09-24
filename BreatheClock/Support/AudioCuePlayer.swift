import AVFoundation
import Foundation
import Combine

/// Main-thread playback ownership. Synthesis runs serially off the main thread;
/// generation checks prevent a cancelled preview/session from starting later.
final class AudioCuePlayer: ObservableObject {
  static let shared = AudioCuePlayer()

  @Published private(set) var previewCue: AudioCue?
  @Published private(set) var previewToneIndex: Int?
  @Published private(set) var playbackError: String?

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let sampleRate: Double = 44_100
  private let format: AVAudioFormat
  private var playbackGeneration = UUID()
  private var audioActive = false
  private var sessionStartPosition: TimeInterval?
  private var sessionStartedAt: TimeInterval?

  var sessionPosition: TimeInterval? {
    guard let start = sessionStartPosition, let startedAt = sessionStartedAt else { return nil }
    // A route/configuration change can invalidate the render clock before its
    // notification reaches the UI. Preserve elapsed time when pausing then,
    // rather than rewinding the session to its last explicit resume point.
    guard let renderTime = player.lastRenderTime,
          let time = player.playerTime(forNodeTime: renderTime), time.sampleTime > 0 else {
      return start + max(0, ProcessInfo.processInfo.systemUptime - startedAt)
    }
    return start + Double(time.sampleTime) / time.sampleRate
  }
  private let renderQueue = DispatchQueue(label: "breatheclock.audio.render", qos: .userInitiated)
  private let cacheLock = NSLock()
  private var bufferCache: [String: AVAudioPCMBuffer] = [:]
  private var cueGainCache: [String: Double] = [:]
  private let targetPeak: Double = 0.45
  private let completionPeak: Double = 0.5

  init() {
    format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.5
  }

  // MARK: - Session playback

  /// Queue the complete score ahead of the audio clock. No foreground timer is
  /// responsible for cues, stage changes, or stopping a finite session.
  /// Repeated cycles share PCM buffers rather than allocating a whole session.
  func startSession(
    cue: AudioCue, routine: Routine, duration: SessionDuration,
    from position: TimeInterval = 0,
    onReady: @escaping (Bool) -> Void,
    onComplete: @escaping () -> Void
  ) {
    stop()
    playbackError = nil
    guard cue != .off else { onReady(true); return }
    let generation = playbackGeneration
    let plan = SessionAudioPlan(routine: routine, duration: duration)
    renderQueue.async { [weak self] in
      guard let self else { return }
      do {
        let segments = plan.segments(from: position)
        var cycles: [SessionAudioPlan.Segment.Content: AVAudioPCMBuffer] = [:]
        var rendered: [SessionAudioPlan.Segment: AVAudioPCMBuffer] = [:]
        var buffers: [(AVAudioPCMBuffer, Bool)] = []
        for segment in segments {
          if let hit = rendered[segment] { buffers.append((hit, segment.loops)); continue }
          let source: AVAudioPCMBuffer?
          if let hit = cycles[segment.content] { source = hit }
          else {
            switch segment.content {
            case .countdown: source = self.countdownBuffer(for: cue, volumeScale: routine.outcomeFamily.cueStyle.volumeScale)
            case .breaths(let phases): source = self.breathingBuffer(cue: cue, phases: phases, style: routine.outcomeFamily.cueStyle)
            }
            cycles[segment.content] = source
          }
          guard let source, let buffer = self.fittedBuffer(source, duration: segment.duration, offset: segment.offset) else {
            throw PlaybackFailure.rendering
          }
          rendered[segment] = buffer
          buffers.append((buffer, segment.loops))
        }
        let completion = plan.sessionDuration == nil ? nil : self.completionBuffer(for: cue)
        if plan.sessionDuration != nil, completion == nil { throw PlaybackFailure.rendering }
        DispatchQueue.main.async { [weak self] in
          guard let self, self.playbackGeneration == generation else { return }
          do {
            try self.activateAudio()
            for (index, entry) in buffers.enumerated() {
              let isLastBreath = index == buffers.count - 1 && plan.sessionDuration != nil
              self.player.scheduleBuffer(entry.0, at: nil, options: entry.1 ? [.loops] : [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard isLastBreath else { return }
                DispatchQueue.main.async {
                  guard let self, self.playbackGeneration == generation else { return }
                  onComplete()
                }
              }
            }
            if let completion {
              self.player.scheduleBuffer(completion, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async {
                  guard let self, self.playbackGeneration == generation else { return }
                  self.stop()
                }
              }
            }
            self.sessionStartPosition = position
            self.sessionStartedAt = ProcessInfo.processInfo.systemUptime
            self.player.play()
            onReady(true)
            if buffers.isEmpty { onComplete() }
          } catch {
            self.failSession(generation: generation, onReady: onReady)
          }
        }
      } catch {
        DispatchQueue.main.async { [weak self] in
          self?.failSession(generation: generation, onReady: onReady)
        }
      }
    }
  }

  private func failSession(generation: UUID, onReady: (Bool) -> Void) {
    guard playbackGeneration == generation else { return }
    stop()
    playbackError = "Audio could not start. Your session is paused; tap Resume to try again."
    onReady(false)
  }

  private func breathingBuffer(cue: AudioCue, phases: [BreathPhase], style: CueStyle) -> AVAudioPCMBuffer? {
    let duration = phases.reduce(0) { $0 + $1.seconds }
    if style.continuous {
      return continuousBuffer(for: cue, phases: phases, cycleDuration: duration, volumeScale: style.volumeScale)
    }
    let frames = Int((duration * sampleRate).rounded())
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
          let output = buffer.floatChannelData?[0] else { return nil }
    buffer.frameLength = AVAudioFrameCount(frames)
    output.initialize(repeating: 0, count: frames)
    var time: TimeInterval = 0
    for phase in phases {
      guard let cueBuffer = discreteBuffer(for: cue, phase: phase.kind, phaseDuration: phase.seconds, volumeScale: style.volumeScale),
            let input = cueBuffer.floatChannelData?[0] else { return nil }
      let start = Int((time * sampleRate).rounded())
      let length = min(Int(cueBuffer.frameLength), Int((phase.seconds * sampleRate).rounded()), frames - start)
      if length > 0 {
        output.advanced(by: start).update(from: input, count: length)
        // A short phase can cut a ringing tail. Fade only that cut, not the
        // normal attack or decay, to avoid clicking at a rapid-breath boundary.
        if length < Int(cueBuffer.frameLength) {
          let fade = min(220, length)
          for i in 0..<fade { output[start + length - fade + i] *= Float(fade - i - 1) / Float(fade) }
        }
      }
      time += phase.seconds
    }
    return buffer
  }

  // MARK: - Sound preview

  func playBoxPreview(_ cue: AudioCue) {
    stop()
    playbackError = nil
    guard cue != .off else { return }
    previewCue = cue
    let generation = playbackGeneration
    renderQueue.async { [weak self] in
      guard let self else { return }
      let phases: [BreathPhase.Kind] = [.inhale, .holdFull, .exhale, .holdEmpty]
      let buffers = phases.compactMap { phase in
        self.discreteBuffer(for: cue, phase: phase, phaseDuration: 4, volumeScale: 1)
          .flatMap { self.fittedBuffer($0, duration: 4) }
      }
      DispatchQueue.main.async { [weak self] in
        guard let self, self.playbackGeneration == generation else { return }
        do {
          guard buffers.count == 4 else { throw PlaybackFailure.rendering }
          try self.activateAudio()
          for (index, buffer) in buffers.enumerated() {
            self.player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
              DispatchQueue.main.async {
                guard let self, self.playbackGeneration == generation else { return }
                if index == 3 { self.stopPreview() }
                else { self.previewToneIndex = index + 1 }
              }
            }
          }
          self.player.play()
          self.previewToneIndex = 0
        } catch {
          self.stop()
          self.playbackError = "Could not play the sound preview. Please try again."
        }
      }
    }
  }

  func stopPreview() {
    guard previewCue != nil else { return }
    stop()
  }

  /// Also cancels pending rendering, all queued samples, and completion callbacks.
  func stop() {
    playbackGeneration = UUID()
    sessionStartPosition = nil
    sessionStartedAt = nil
    playbackError = nil
    player.stop()
    previewCue = nil
    previewToneIndex = nil
    engine.pause()
    if audioActive {
      #if os(iOS)
      try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
      #endif
      audioActive = false
    }
  }

  private enum PlaybackFailure: Error { case rendering }

  private func activateAudio() throws {
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setActive(true)
    #endif
    audioActive = true
    if !engine.isRunning { try engine.start() }
  }

  /// Silence is the natural space between audible breathing cues, not a
  /// keepalive track. Audio Off never schedules or activates these buffers.
  private func fittedBuffer(_ source: AVAudioPCMBuffer, duration: TimeInterval, offset: TimeInterval = 0) -> AVAudioPCMBuffer? {
    let frames = AVAudioFrameCount((duration * sampleRate).rounded())
    let skip = Int((offset * sampleRate).rounded())
    guard frames > 0, let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          let output = result.floatChannelData?[0], let input = source.floatChannelData?[0] else { return nil }
    result.frameLength = frames
    output.initialize(repeating: 0, count: Int(frames))
    let count = min(Int(frames), max(0, Int(source.frameLength) - skip))
    if count > 0 { output.update(from: input + skip, count: count) }
    return result
  }

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
    let key = "d-\(cue.rawValue)-\(phase)-\(phaseDuration ?? -1)-\(Int(volumeScale * 100))"
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
    let key = "c-\(cue.rawValue)-\(phases)-\(cycleDuration)-\(Int(volumeScale * 100))"
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
