import Foundation

struct Routine: Identifiable, Hashable {
  let id: String
  let category: String
  let name: String
  let description: String
  let phases: [BreathPhase]
  let intensity: Intensity
  let safetyNote: String?
  let patternOverride: String?
  let reducedPhases: [BreathPhase]?
  let program: [ProgramStage]?
  let mode: RoutineMode

  init(
    id: String,
    category: String,
    name: String,
    description: String,
    phases: [BreathPhase],
    intensity: Intensity = .gentle,
    safetyNote: String? = nil,
    patternOverride: String? = nil,
    reducedPhases: [BreathPhase]? = nil,
    program: [ProgramStage]? = nil,
    mode: RoutineMode = .paced
  ) {
    self.id = id
    self.category = category
    self.name = name
    self.description = description
    self.phases = phases
    self.intensity = intensity
    self.safetyNote = safetyNote
    self.patternOverride = patternOverride
    self.reducedPhases = reducedPhases
    self.program = program
    self.mode = mode
  }

  var isTimed: Bool {
    switch mode {
    case .assessment: return false
    case .paced: return isProgram || !phases.isEmpty
    }
  }

  var isProgram: Bool {
    !(program?.isEmpty ?? true)
  }

  var hasReducedVariant: Bool {
    !(reducedPhases?.isEmpty ?? true)
  }

  /// The outcome family drives sensory matching (cue intensity, grounding).
  var outcomeFamily: OutcomeFamily {
    if mode == .assessment { return .assessment }
    if id == "coherence" { return .coherence }
    switch category {
    case "Calm": return .downRegulate
    case "Focus": return .focus
    case "Train": return .train
    case "Contemplative": return .contemplative
    case "Energize": return .upRegulate
    case "Release": return .somaticRelease
    default: return .downRegulate
    }
  }

  /// Returns the routine with its eased pattern swapped in, when a reduced
  /// variant exists and the eased pace is selected. Otherwise returns self.
  func resolved(for pace: BreathPace) -> Routine {
    guard pace == .eased, let reducedPhases, !reducedPhases.isEmpty else { return self }
    return Routine(
      id: id,
      category: category,
      name: name,
      description: description,
      phases: reducedPhases,
      intensity: intensity,
      safetyNote: safetyNote,
      patternOverride: patternOverride,
      reducedPhases: reducedPhases,
      program: program,
      mode: mode
    )
  }

  var patternText: String {
    if let patternOverride { return patternOverride }
    if mode == .assessment { return "Measure" }
    if isProgram { return "Guided" }
    return phases.isEmpty ? "Untimed" : phases.map { $0.displaySeconds }.joined(separator: " · ")
  }

  var requiresAcknowledgement: Bool {
    intensity == .intense
  }

  var cycleDuration: TimeInterval {
    phases.reduce(0) { $0 + $1.seconds }
  }

  var programTotalDuration: TimeInterval {
    program?.reduce(0) { $0 + $1.duration } ?? 0
  }

  var hasHoldPhases: Bool {
    if let program {
      return program.contains { stage in stage.phases.contains { $0.kind.isHold } }
    }
    return phases.contains { $0.kind.isHold }
  }

  func alignedSessionDuration(for duration: SessionDuration) -> TimeInterval? {
    if isProgram { return programTotalDuration }
    guard let targetSeconds = duration.seconds else { return nil }
    guard isTimed, cycleDuration > 0 else { return targetSeconds }

    let cycles = max(1, ceil(targetSeconds / cycleDuration))
    return cycles * cycleDuration
  }

  func alignmentText(for duration: SessionDuration) -> String? {
    guard
      !isProgram,
      let targetSeconds = duration.seconds,
      let alignedSeconds = alignedSessionDuration(for: duration),
      alignedSeconds > targetSeconds + 0.5
    else {
      return nil
    }

    return "Completes at \(alignedSeconds.clockText)"
  }

  func state(at elapsed: TimeInterval) -> BreathState {
    if let program, !program.isEmpty {
      return programState(at: elapsed, stages: program)
    }
    return cyclicState(in: phases, elapsed: elapsed, stageIndex: 0, stageTitle: nil)
  }

  private func programState(at elapsed: TimeInterval, stages: [ProgramStage]) -> BreathState {
    var stageStart: TimeInterval = 0
    for (index, stage) in stages.enumerated() {
      let stageEnd = stageStart + stage.duration
      if elapsed < stageEnd || index == stages.count - 1 {
        let localElapsed = max(0, elapsed - stageStart)
        return cyclicState(
          in: stage.phases,
          elapsed: localElapsed,
          stageIndex: index,
          stageTitle: stage.title
        )
      }
      stageStart = stageEnd
    }
    return cyclicState(in: stages[0].phases, elapsed: 0, stageIndex: 0, stageTitle: stages[0].title)
  }

  private func cyclicState(
    in phases: [BreathPhase],
    elapsed: TimeInterval,
    stageIndex: Int,
    stageTitle: String?
  ) -> BreathState {
    let cycle = phases.reduce(0) { $0 + $1.seconds }
    guard !phases.isEmpty, cycle > 0 else {
      return BreathState(
        phaseIndex: 0,
        cycleIndex: 0,
        phase: BreathPhase(kind: .inhale, seconds: 1),
        phaseElapsed: 0,
        cycleElapsed: 0,
        pupilScale: 0,
        progressInCycle: 0,
        stageIndex: stageIndex,
        stageTitle: stageTitle
      )
    }

    let cycleElapsed = elapsed.truncatingRemainder(dividingBy: cycle)
    let cycleIndex = Int(elapsed / cycle)
    var cursor: TimeInterval = 0

    for index in phases.indices {
      let phase = phases[index]
      let nextCursor = cursor + phase.seconds
      if cycleElapsed < nextCursor || index == phases.count - 1 {
        let phaseElapsed = max(0, cycleElapsed - cursor)
        return BreathState(
          phaseIndex: index,
          cycleIndex: cycleIndex,
          phase: phase,
          phaseElapsed: phaseElapsed,
          cycleElapsed: cycleElapsed,
          pupilScale: pupilScale(for: phase, elapsed: phaseElapsed),
          progressInCycle: cycleElapsed / cycle,
          stageIndex: stageIndex,
          stageTitle: stageTitle
        )
      }
      cursor = nextCursor
    }

    return BreathState(
      phaseIndex: 0,
      cycleIndex: cycleIndex,
      phase: phases[0],
      phaseElapsed: 0,
      cycleElapsed: cycleElapsed,
      pupilScale: 0,
      progressInCycle: 0,
      stageIndex: stageIndex,
      stageTitle: stageTitle
    )
  }

  private func pupilScale(for phase: BreathPhase, elapsed: TimeInterval) -> Double {
    let progress = min(max(elapsed / phase.seconds, 0), 1)
    let eased = 0.5 - 0.5 * cos(Double.pi * progress)

    switch phase.kind {
    case .inhale:
      return eased
    case .exhale:
      return 1 - eased
    case .holdFull:
      return 1
    case .holdEmpty:
      return 0
    }
  }

  static let coherence = Routine(
    id: "coherence",
    category: "Focus",
    name: "Coherence",
    description: "Even breaths at about six per minute to steady heart rhythm and focus. Smooth, and through the nose.",
    phases: [
      BreathPhase(kind: .inhale, seconds: 5.5),
      BreathPhase(kind: .exhale, seconds: 5.5)
    ]
  )

  private static func wimHofRoundPhases() -> [BreathPhase] {
    var phases: [BreathPhase] = []
    for _ in 0..<30 {
      phases.append(BreathPhase(kind: .inhale, seconds: 1.5, action: .active))
      phases.append(BreathPhase(kind: .exhale, seconds: 1.5, action: .passive))
    }
    phases.append(BreathPhase(kind: .holdEmpty, seconds: 45))
    phases.append(BreathPhase(kind: .inhale, seconds: 2, action: .active))
    phases.append(BreathPhase(kind: .holdFull, seconds: 15))
    return phases
  }

  /// A guided contemplative descent: steady the rhythm, then lengthen the
  /// exhale stage by stage toward stillness. Total ~8.5 minutes.
  private static func samadhiProgram() -> [ProgramStage] {
    [
      ProgramStage(
        title: "Settle",
        phases: [
          BreathPhase(kind: .inhale, seconds: 4),
          BreathPhase(kind: .exhale, seconds: 6)
        ],
        duration: 90
      ),
      ProgramStage(
        title: "Coherence",
        phases: [
          BreathPhase(kind: .inhale, seconds: 5.5),
          BreathPhase(kind: .exhale, seconds: 5.5)
        ],
        duration: 180
      ),
      ProgramStage(
        title: "Lengthen",
        phases: [
          BreathPhase(kind: .inhale, seconds: 4),
          BreathPhase(kind: .exhale, seconds: 8)
        ],
        duration: 150
      ),
      ProgramStage(
        title: "Stillness",
        phases: [
          BreathPhase(kind: .inhale, seconds: 4),
          BreathPhase(kind: .exhale, seconds: 10)
        ],
        duration: 90
      )
    ]
  }

  static let all: [Routine] = [
    Routine(
      id: "calm",
      category: "Calm",
      name: "Calm",
      description: "A short inhale and a long, slow exhale to settle the nervous system. Nasal and unforced.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 4),
        BreathPhase(kind: .exhale, seconds: 8)
      ]
    ),
    Routine(
      id: "sleep",
      category: "Calm",
      name: "Sleep",
      description: "The 4-7-8 wind-down: inhale four, hold seven, exhale eight. Ease the hold if it ever strains.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 4),
        BreathPhase(kind: .holdFull, seconds: 7),
        BreathPhase(kind: .exhale, seconds: 8)
      ],
      safetyNote: "If the seven-count hold feels hard, shorten it. The breath should never feel forced.",
      reducedPhases: [
        BreathPhase(kind: .inhale, seconds: 4),
        BreathPhase(kind: .holdFull, seconds: 4),
        BreathPhase(kind: .exhale, seconds: 6)
      ]
    ),
    Routine(
      id: "physiological-sigh",
      category: "Calm",
      name: "Physiological Sigh",
      description: "A double inhale through the nose, then a long exhale — the fastest way to shed acute stress.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .inhale, seconds: 1),
        BreathPhase(kind: .exhale, seconds: 8)
      ]
    ),
    .coherence,
    Routine(
      id: "box",
      category: "Focus",
      name: "Box",
      description: "Equal inhale, hold, exhale, hold for composure under pressure. Shorten the count if the holds strain.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 4),
        BreathPhase(kind: .holdFull, seconds: 4),
        BreathPhase(kind: .exhale, seconds: 4),
        BreathPhase(kind: .holdEmpty, seconds: 4)
      ],
      safetyNote: "If the holds create strain, drop to a shorter count and build gradually.",
      reducedPhases: [
        BreathPhase(kind: .inhale, seconds: 3),
        BreathPhase(kind: .holdFull, seconds: 3),
        BreathPhase(kind: .exhale, seconds: 3),
        BreathPhase(kind: .holdEmpty, seconds: 3)
      ]
    ),
    Routine(
      id: "box-5",
      category: "Focus",
      name: "Box 5",
      description: "The square breath lengthened to five seconds a side as your tolerance grows.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 5),
        BreathPhase(kind: .holdFull, seconds: 5),
        BreathPhase(kind: .exhale, seconds: 5),
        BreathPhase(kind: .holdEmpty, seconds: 5)
      ]
    ),
    Routine(
      id: "light-breathing",
      category: "Train",
      name: "Light Breathing",
      description: "Slow, light nasal breathing with a short, comfortable pause after the exhale to build CO2 tolerance. Never force the pause.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .exhale, seconds: 3),
        BreathPhase(kind: .holdEmpty, seconds: 3)
      ],
      safetyNote: "Keep the pause easy. If you gasp on the next breath, it was too long.",
      reducedPhases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .exhale, seconds: 3),
        BreathPhase(kind: .holdEmpty, seconds: 1)
      ]
    ),
    Routine(
      id: "kumbhaka",
      category: "Train",
      name: "Kumbhaka",
      description: "A gentle retention: easy inhale, longer exhale, then a brief empty pause. Back off the moment you feel air hunger.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .exhale, seconds: 4),
        BreathPhase(kind: .holdEmpty, seconds: 2)
      ],
      safetyNote: "Skip or shorten the empty hold if you feel air hunger.",
      reducedPhases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .exhale, seconds: 4),
        BreathPhase(kind: .holdEmpty, seconds: 1)
      ]
    ),
    Routine(
      id: "bolt",
      category: "Train",
      name: "BOLT Score",
      description: "A simple measure of CO2 tolerance. After a normal exhale, time the seconds until the first clear urge to breathe — never your maximum hold.",
      phases: [],
      safetyNote: "Measure the first urge, not your limit. Stop if you feel any strain.",
      mode: .assessment
    ),
    Routine(
      id: "bhramari",
      category: "Contemplative",
      name: "Bhramari",
      description: "Inhale through the nose, then hum the exhale — the bee breath. The soft sound is the practice itself.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 4),
        BreathPhase(kind: .exhale, seconds: 8, humming: true)
      ]
    ),
    Routine(
      id: "alternate-nostril",
      category: "Contemplative",
      name: "Alternate Nostril",
      description: "Nadi shodhana — breathe in through one nostril and out through the other, alternating sides as the app guides.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 4, nostrilSide: .left),
        BreathPhase(kind: .exhale, seconds: 4, nostrilSide: .right),
        BreathPhase(kind: .inhale, seconds: 4, nostrilSide: .right),
        BreathPhase(kind: .exhale, seconds: 4, nostrilSide: .left)
      ]
    ),
    Routine(
      id: "samadhi",
      category: "Contemplative",
      name: "Samadhi",
      description: "A guided descent toward stillness: settle, find a coherent rhythm, then lengthen the exhale stage by stage. Just follow the count.",
      phases: [],
      patternOverride: "Guided · 4 stages",
      program: samadhiProgram()
    ),
    Routine(
      id: "energy",
      category: "Energize",
      name: "Energy",
      description: "Brisk, even breaths to raise alertness before effort. Stay seated, and stop if you feel light-headed.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 3, action: .active),
        BreathPhase(kind: .exhale, seconds: 3)
      ],
      intensity: .moderate,
      safetyNote: "Stay seated. Stop if you feel light-headed or tingly."
    ),
    Routine(
      id: "wim-hof",
      category: "Energize",
      name: "Wim Hof",
      description: "Rounds of brisk, full breaths, then an exhale hold and a recovery breath. Intense — never in water, while driving, or standing.",
      phases: wimHofRoundPhases(),
      intensity: .intense,
      safetyNote: "Thirty brisk breaths, then an exhale hold, then a recovery breath. Sit or lie down, and end early if you feel faint. Never in water, while driving, or standing.",
      patternOverride: "Breathe · Hold · Recover"
    ),
    Routine(
      id: "rebirthing",
      category: "Release",
      name: "Rebirthing",
      description: "Continuous connected breathing with no pauses, to surface and release held emotion. Intense; give yourself time to settle before and after.",
      phases: [
        BreathPhase(kind: .inhale, seconds: 2),
        BreathPhase(kind: .exhale, seconds: 2)
      ],
      intensity: .intense,
      safetyNote: "Connected breathing can surface strong emotion and cause tingling or dizziness. Lie down somewhere safe and let yourself settle afterward."
    )
  ]

  static var grouped: [(category: String, routines: [Routine])] {
    let categories = ["Calm", "Focus", "Train", "Contemplative", "Energize", "Release"]
    return categories.compactMap { category in
      let routines = all.filter { $0.category == category }
      return routines.isEmpty ? nil : (category, routines)
    }
  }

  static func byID(_ id: String) -> Routine? {
    all.first { $0.id == id }
  }
}

struct BreathPhase: Hashable {
  let kind: Kind
  let seconds: TimeInterval
  let route: BreathRoute
  let action: PhaseAction
  let nostrilSide: NostrilSide?
  let humming: Bool

  init(
    kind: Kind,
    seconds: TimeInterval,
    route: BreathRoute = .nasal,
    action: PhaseAction = .passive,
    nostrilSide: NostrilSide? = nil,
    humming: Bool = false
  ) {
    self.kind = kind
    self.seconds = seconds
    self.route = route
    self.action = action
    self.nostrilSide = nostrilSide
    self.humming = humming
  }

  var label: String {
    kind.label
  }

  var guidanceLabel: String {
    if humming { return "Hum" }
    if let nostrilSide { return "\(label) · \(nostrilSide.label)" }
    return label
  }

  var displaySeconds: String {
    if seconds.truncatingRemainder(dividingBy: 1) == 0 {
      return String(Int(seconds))
    }
    return String(format: "%.3f", seconds)
      .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
  }

  enum Kind: String, Hashable {
    case inhale
    case holdFull
    case exhale
    case holdEmpty

    var isHold: Bool {
      switch self {
      case .holdFull, .holdEmpty:
        true
      case .inhale, .exhale:
        false
      }
    }

    var label: String {
      switch self {
      case .inhale: "Inhale"
      case .holdFull, .holdEmpty: "Hold"
      case .exhale: "Exhale"
      }
    }
  }
}

/// One segment of a guided program: a sub-pattern held for a fixed duration.
struct ProgramStage: Hashable {
  let title: String
  let phases: [BreathPhase]
  let duration: TimeInterval
}

struct BreathState {
  let phaseIndex: Int
  let cycleIndex: Int
  let phase: BreathPhase
  let phaseElapsed: TimeInterval
  let cycleElapsed: TimeInterval
  let pupilScale: Double
  let progressInCycle: Double
  var stageIndex: Int = 0
  var stageTitle: String? = nil

  var phaseRemaining: TimeInterval {
    max(0, phase.seconds - phaseElapsed)
  }

  var countdownDigit: Int {
    max(1, Int(ceil(phaseRemaining)))
  }

  var boundaryKey: String {
    "\(stageIndex)-\(cycleIndex)-\(phaseIndex)"
  }
}

struct SessionDuration: Identifiable, Equatable {
  let seconds: TimeInterval?
  let label: String
  let unit: String?

  var id: String {
    seconds.map { String(Int($0)) } ?? "infinite"
  }

  var storedSeconds: Int {
    seconds.map { Int($0) } ?? 0
  }

  var displayText: String {
    guard let seconds else { return "∞" }
    let minutes = Int(seconds / 60)
    return "\(minutes):00"
  }

  static let options: [SessionDuration] = [
    SessionDuration(seconds: 60, label: "1", unit: "m"),
    SessionDuration(seconds: 180, label: "3", unit: "m"),
    SessionDuration(seconds: 300, label: "5", unit: "m"),
    SessionDuration(seconds: 600, label: "10", unit: "m"),
    SessionDuration(seconds: 1200, label: "20", unit: "m"),
    SessionDuration(seconds: nil, label: "∞", unit: nil)
  ]

  static func fromStored(seconds: Int) -> SessionDuration {
    options.first { $0.storedSeconds == seconds } ?? options[1]
  }
}

enum AudioCue: String, CaseIterable, Identifiable {
  case off
  case bowl
  case fork
  case wood
  case hum
  case turf

  var id: String { rawValue }

  var title: String {
    switch self {
    case .off: "Off"
    case .bowl: "Bowl"
    case .fork: "Fork"
    case .wood: "Wood"
    case .hum: "Hum"
    case .turf: "Turf"
    }
  }

  var detail: String? {
    switch self {
    case .off: nil
    case .bowl: "Himalayan"
    case .fork: "Pure tone"
    case .wood: "Mokugyo"
    case .hum: "Atmospheric"
    case .turf: "Web version"
    }
  }
}

enum BreathRoute: String, Hashable {
  case nasal
  case mouth
}

enum PhaseAction: String, Hashable {
  case passive
  case active
  case forceful
}

enum NostrilSide: String, Hashable {
  case left
  case right

  var label: String {
    switch self {
    case .left: "Left"
    case .right: "Right"
    }
  }
}

enum Intensity: String, Hashable {
  case gentle
  case moderate
  case intense
}

enum RoutineMode: String, Hashable {
  case paced
  case assessment
}

enum BreathPace: String, Hashable, CaseIterable, Identifiable {
  case eased
  case full

  var id: String { rawValue }

  var label: String {
    switch self {
    case .eased: "Eased"
    case .full: "Full"
    }
  }
}

/// Groups routines by the state they target, which drives sensory matching.
enum OutcomeFamily: Hashable {
  case downRegulate
  case coherence
  case focus
  case train
  case contemplative
  case upRegulate
  case somaticRelease
  case assessment

  var cueStyle: CueStyle {
    switch self {
    case .downRegulate, .train, .contemplative, .somaticRelease: return .soft
    case .coherence: return .coherent
    case .focus, .upRegulate: return .crisp
    case .assessment: return .silent
    }
  }

  /// Somatic-release work needs a grounding arc before and after.
  var needsGrounding: Bool {
    self == .somaticRelease
  }
}

/// How loud and how textured the breath cues should be for a family.
enum CueStyle: Hashable {
  case soft       // down-regulation: quiet, sparse, predictable
  case coherent   // coherence: continuous, even, non-startling
  case crisp      // up-regulation / focus: clear count and energy
  case silent     // assessment: distraction-free

  var volumeScale: Double {
    switch self {
    case .soft: return 0.7
    case .coherent: return 0.8
    case .crisp: return 1.0
    case .silent: return 0
    }
  }

  /// Coherence prefers one sustained gliding tone over discrete chimes.
  var continuous: Bool {
    self == .coherent
  }
}

enum BreatheSafety {
  static let disclaimer = "Plume offers breathing exercises for general wellbeing. It is not medical advice and not a treatment for any condition. Comfort matters more than hitting the numbers — never force a hold or a breath. Stop and rest if you feel faint, breathless, or distressed."

  static let intenseRules = "Practice only while seated or lying down. Never in water, while driving, or standing unsupported. Rapid breathing and breath holds can cause tingling, dizziness, or fainting."

  static let contraindications = [
    "Pregnancy",
    "Heart disease or high blood pressure",
    "Epilepsy or seizure history",
    "Serious or recent respiratory illness",
    "A history of fainting or panic attacks"
  ]
}
