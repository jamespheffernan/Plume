import AVFoundation
import Foundation

final class AudioCuePlayer {
  static let shared = AudioCuePlayer()

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let sampleRate: Double = 44_100
  private let format: AVAudioFormat
  private var pendingPreviewWorkItems: [DispatchWorkItem] = []

  private init() {
    format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.42
  }

  func play(
    _ cue: AudioCue,
    for phase: BreathPhase.Kind,
    phaseDuration: TimeInterval? = nil,
    style: CueStyle = .crisp
  ) {
    guard cue != .off, style.volumeScale > 0 else { return }
    let buffer = style.continuous
      ? makeGlideBuffer(for: cue, phase: phase, phaseDuration: phaseDuration, volumeScale: style.volumeScale)
      : makeBuffer(for: cue, phase: phase, phaseDuration: phaseDuration, volumeScale: style.volumeScale)
    guard let buffer else { return }
    startIfNeeded()
    player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    if !player.isPlaying {
      player.play()
    }
  }

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
    guard cue != .off else { return }
    guard let buffer = makeCompletionBuffer(for: cue) else { return }
    startIfNeeded()
    player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    if !player.isPlaying {
      player.play()
    }
  }

  private func stopPreview() {
    pendingPreviewWorkItems.forEach { $0.cancel() }
    pendingPreviewWorkItems.removeAll()
    player.stop()
  }

  private func startIfNeeded() {
    #if os(iOS)
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    #endif

    if !engine.isRunning {
      try? engine.start()
    }
  }

  private func makeBuffer(
    for cue: AudioCue,
    phase: BreathPhase.Kind,
    phaseDuration: TimeInterval?,
    volumeScale: Double = 1.0
  ) -> AVAudioPCMBuffer? {
    let profile = toneProfile(for: cue, phase: phase, phaseDuration: phaseDuration)
    let duration = profile.duration
    let frames = AVAudioFrameCount(duration * sampleRate)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
    buffer.frameLength = frames
    guard let channel = buffer.floatChannelData?[0] else { return nil }

    for frame in 0..<Int(frames) {
      let time = Double(frame) / sampleRate
      let value: Double

      switch cue {
      case .off:
        value = 0
      case .bowl:
        value = bowlSample(time: time, frequency: profile.frequency, duration: duration)
      case .fork:
        value = forkSample(time: time, frequency: profile.frequency, duration: duration)
      case .wood:
        value = woodSample(time: time, frequency: profile.frequency, duration: duration)
      case .hum:
        value = humSample(time: time, frequency: profile.frequency, duration: duration)
      case .turf:
        value = turfWebSample(time: time, frequency: profile.frequency, duration: duration)
      }

      channel[frame] = Float(max(-1, min(1, value * profile.amplitudeScale * 0.65 * volumeScale)))
    }

    return buffer
  }

  /// A soft, sustained tone that glides in pitch across the phase, giving the
  /// coherent (continuous) cue style its even, non-startling character.
  private func makeGlideBuffer(
    for cue: AudioCue,
    phase: BreathPhase.Kind,
    phaseDuration: TimeInterval?,
    volumeScale: Double
  ) -> AVAudioPCMBuffer? {
    let duration = max(phaseDuration ?? 5.0, 1.0)
    let frames = AVAudioFrameCount(duration * sampleRate)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
    buffer.frameLength = frames
    guard let channel = buffer.floatChannelData?[0] else { return nil }

    let inhaleFreq = frequency(for: cue, phase: .inhale)
    let exhaleFreq = frequency(for: cue, phase: .exhale)
    let startFreq: Double
    let endFreq: Double
    switch phase {
    case .inhale:
      startFreq = exhaleFreq
      endFreq = inhaleFreq
    case .exhale:
      startFreq = inhaleFreq
      endFreq = exhaleFreq
    case .holdFull:
      startFreq = inhaleFreq
      endFreq = inhaleFreq
    case .holdEmpty:
      startFreq = exhaleFreq
      endFreq = exhaleFreq
    }

    let dt = 1.0 / sampleRate
    let attack = min(0.8, duration * 0.25)
    let release = min(1.2, duration * 0.35)
    var phaseAccumulator = 0.0

    for frame in 0..<Int(frames) {
      let time = Double(frame) / sampleRate
      let progress = min(max(time / duration, 0), 1)
      let eased = 0.5 - 0.5 * cos(Double.pi * progress)
      let freq = startFreq + (endFreq - startFreq) * eased
      phaseAccumulator += 2 * .pi * freq * dt
      let tone = sin(phaseAccumulator) * 0.82 + sin(phaseAccumulator * 2) * 0.12
      let env = sustainEnvelope(time: time, duration: duration, attack: attack, release: release)
      let value = tone * env * 0.18 * volumeScale
      channel[frame] = Float(max(-1, min(1, value)))
    }

    return buffer
  }

  private func makeCompletionBuffer(for cue: AudioCue) -> AVAudioPCMBuffer? {
    let duration = completionDuration(for: cue)
    let frames = AVAudioFrameCount(duration * sampleRate)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
    buffer.frameLength = frames
    guard let channel = buffer.floatChannelData?[0] else { return nil }

    for frame in 0..<Int(frames) {
      let time = Double(frame) / sampleRate
      let value = completionSample(for: cue, time: time, duration: duration)
      channel[frame] = Float(max(-1, min(1, value * 0.65)))
    }

    return buffer
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

    let duration = cue == .hum && isHold
      ? max(phaseDuration ?? baseDuration, 1.2)
      : baseDuration * (isHold ? 0.7 : 1.0)

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
    case .wood:
      switch phase {
      case .inhale: return 293.66
      case .holdFull: return 440.00
      case .exhale: return 220.00
      case .holdEmpty: return 174.61
      }
    case .hum:
      switch phase {
      case .inhale: return 220.00
      case .holdFull: return 329.63
      case .exhale: return 164.81
      case .holdEmpty: return 130.81
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
    case .wood:
      return 0.55
    case .hum:
      return 4.5
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
    case .wood:
      return 0.95
    case .hum:
      return 4.2
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

  private func woodSample(time: Double, frequency: Double, duration: Double) -> Double {
    let triangle = 2 * abs(2 * ((frequency * time) - floor(frequency * time + 0.5))) - 1
    let burst = time < 0.04 ? Double.random(in: -1...1) * (1 - time / 0.04) * 0.18 : 0
    return (triangle * 0.5 + burst) * envelope(time: time, duration: duration, attack: 0.003, decay: 9.0) * 0.42
  }

  private func humSample(time: Double, frequency: Double, duration: Double) -> Double {
    let detunes = [-7.0, 0, 6.0]
    let tone = detunes.reduce(0.0) { partial, cents in
      let tuned = frequency * pow(2, cents / 1200)
      let saw = 2 * (tuned * time - floor(0.5 + tuned * time))
      return partial + saw / Double(detunes.count)
    }
    return tone * sustainEnvelope(time: time, duration: duration, attack: 0.6, release: 1.2) * 0.2
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
    case .wood:
      return woodCompletionTap(time: time, delay: 0.00, frequency: 293.66, amplitude: 0.75)
        + woodCompletionTap(time: time, delay: 0.22, frequency: 220.00, amplitude: 0.55)
        + woodCompletionTap(time: time, delay: 0.44, frequency: 174.61, amplitude: 0.38)
    case .hum:
      let root = sin(2 * .pi * 146.83 * time) * 0.76
      let fifth = sin(2 * .pi * 220.00 * time) * 0.36
      let octave = sin(2 * .pi * 293.66 * time) * 0.20
      return (root + fifth + octave)
        * sustainEnvelope(time: time, duration: duration, attack: 0.45, release: 1.35)
        * 0.22
    case .turf:
      let first = turfCompletionPip(time: time, frequency: 392.00, duration: 0.2)
      let second = time >= 0.24
        ? turfCompletionPip(time: time - 0.24, frequency: 523.25, duration: 0.26) * 0.82
        : 0
      return first + second
    }
  }

  private func woodCompletionTap(
    time: Double,
    delay: Double,
    frequency: Double,
    amplitude: Double
  ) -> Double {
    guard time >= delay else { return 0 }
    return woodSample(time: time - delay, frequency: frequency, duration: 0.55) * amplitude
  }

  private func turfCompletionPip(time: Double, frequency: Double, duration: Double) -> Double {
    guard time <= duration else { return 0 }
    return turfWebSample(time: time, frequency: frequency, duration: duration) * 1.55
  }

  private func envelope(time: Double, duration: Double, attack: Double, decay: Double) -> Double {
    if time < attack {
      return max(0, time / attack)
    }
    let normalized = min(max((time - attack) / max(duration - attack, 0.001), 0), 1)
    return exp(-decay * normalized)
  }

  private func sustainEnvelope(time: Double, duration: Double, attack: Double, release: Double) -> Double {
    if time < attack {
      return max(0, time / attack)
    }
    if time > duration - release {
      return max(0, (duration - time) / release)
    }
    return 1
  }
}

private struct ToneProfile {
  let frequency: Double
  let amplitudeScale: Double
  let duration: Double
}
