import SwiftUI

struct LibraryView: View {
  let scheme: BreatheScheme
  let selectedRoutine: Routine
  let onSelectRoutine: (Routine) -> Void
  let onSettings: () -> Void
  /// True only for the cold-launch appearance of the Library, so the staggered
  /// entrance plays once per app launch and not when returning from Setup or
  /// Settings. The root flips its flag via `onEntrancePlayed`.
  var animateEntrance: Bool = false
  var onEntrancePlayed: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selectedCategory: String?
  @State private var entranceShown = false

  private var categories: [String] {
    Routine.grouped.map(\.category)
  }

  private var groups: [(category: String, routines: [Routine])] {
    guard let selectedCategory else { return Routine.grouped }
    return Routine.grouped.filter { $0.category == selectedCategory }
  }

  /// Friendlier label for the one category whose name reads clinically as a pill.
  private func pillLabel(_ category: String) -> String {
    category == "Contemplative" ? "Inward" : category
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      reveal(0) {
        header
          .padding(.horizontal, 28)
          .padding(.top, 24)
          .padding(.bottom, 18)
      }

      reveal(1) {
        pillRow
          .padding(.bottom, 18)
      }

      reveal(2) {
        Rectangle()
          .fill(scheme.hairline)
          .frame(height: 1)
          .padding(.horizontal, 28)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          ForEach(Array(groups.enumerated()), id: \.element.category) { offset, group in
            categorySection(
              group,
              showLabel: selectedCategory == nil,
              baseIndex: entranceBaseIndex(forGroupOffset: offset)
            )
          }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 44)
      }
      .scrollIndicators(.hidden)
    }
    .background(scheme.paper)
    // Continue the system icon-zoom's deceleration: the whole layout finishes
    // the last sliver of the zoom (0.985 → 1) on the breath wave as it settles.
    .scaleEffect(entranceScale, anchor: .top)
    .animation(launchAnimates ? LaunchEntrance.curve : nil, value: entranceShown)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
    .animation(.easeInOut(duration: 0.28), value: selectedCategory)
    .onAppear(perform: playEntrance)
  }

  // MARK: Launch entrance

  /// Whether this appearance should run the staggered settle (cold launch, motion on).
  private var launchAnimates: Bool { animateEntrance && !reduceMotion }

  private var entranceScale: CGFloat {
    guard launchAnimates else { return 1 }
    return entranceShown ? 1 : LaunchEntrance.containerScaleFrom
  }

  /// Total number of staggerable elements at launch (header, pills, rule, then
  /// each section's label + its rows), used to taper the rise down the page.
  private var entranceItemCount: Int {
    3 + Routine.grouped.reduce(0) { $0 + 1 + $1.routines.count }
  }

  /// Stagger slot of a section's label; rows follow at `+1 + rowOffset`.
  private func entranceBaseIndex(forGroupOffset offset: Int) -> Int {
    3 + Routine.grouped.prefix(offset).reduce(0) { $0 + 1 + $1.routines.count }
  }

  /// Wraps a section so it rises and fades in on its own delayed breath wave.
  /// When the entrance is not animating (return navigation, Reduce Motion) the
  /// content renders untouched, so there is no hidden first frame.
  @ViewBuilder
  private func reveal<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
    if launchAnimates {
      content().modifier(LaunchReveal(index: index, total: entranceItemCount, shown: entranceShown))
    } else {
      content()
    }
  }

  private func playEntrance() {
    guard !entranceShown else { return }
    if launchAnimates {
      entranceShown = true
      onEntrancePlayed()
    } else {
      // Settle instantly with no animation, then report so the flag advances.
      var settle = Transaction()
      settle.disablesAnimations = true
      withTransaction(settle) { entranceShown = true }
      if animateEntrance { onEntrancePlayed() }
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text("Plume")
        .font(BreatheFont.display(30, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .tracking(-0.4)

      Spacer()

      Button(action: onSettings) {
        HStack(spacing: 4) {
          ForEach(0..<3, id: \.self) { _ in
            Circle()
              .fill(scheme.ink)
              .frame(width: 4, height: 4)
          }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Settings")
    }
  }

  private var pillRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        pill(title: "All", category: nil)
        ForEach(categories, id: \.self) { category in
          pill(title: pillLabel(category), category: category)
        }
      }
      .padding(.horizontal, 28)
    }
  }

  private func pill(title: String, category: String?) -> some View {
    let isSelected = selectedCategory == category
    return Button {
      withAnimation(.easeInOut(duration: 0.25)) { selectedCategory = category }
    } label: {
      Text(title)
        .font(BreatheFont.utility(12, weight: isSelected ? .semibold : .regular))
        .tracking(0.6)
        .foregroundStyle(isSelected ? scheme.paper : scheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(isSelected ? scheme.ink : Color.clear))
        .overlay(Capsule().stroke(scheme.ink.opacity(isSelected ? 0 : 0.2), lineWidth: 1))
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(category == nil ? "All practices" : "\(title) practices")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func categorySection(
    _ group: (category: String, routines: [Routine]),
    showLabel: Bool,
    baseIndex: Int
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      if showLabel {
        reveal(baseIndex) {
          Text(pillLabel(group.category))
            .font(BreatheFont.display(14, weight: .regular, italic: true))
            .foregroundStyle(scheme.muted)
            .tracking(0.4)
        }
      }

      VStack(spacing: 0) {
        ForEach(Array(group.routines.enumerated()), id: \.element.id) { rowOffset, routine in
          reveal(baseIndex + 1 + rowOffset) {
            routineRow(routine)
          }
        }
      }
    }
  }

  private func routineRow(_ routine: Routine) -> some View {
    Button {
      onSelectRoutine(routine)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(routine.name)
            .font(BreatheFont.display(19, weight: routine == selectedRoutine ? .semibold : .regular))
            .foregroundStyle(scheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

          Text(routine.description)
            .font(BreatheFont.utility(12, weight: .light))
            .foregroundStyle(scheme.muted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 10)

        Text(routine.patternText)
          .font(BreatheFont.display(14, weight: .light))
          .foregroundStyle(scheme.ink)
          .monospacedDigit()
          .tracking(0.7)
          .lineLimit(1)
      }
      .padding(.vertical, 15)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(scheme.hairline)
        .frame(height: 1)
    }
    .accessibilityLabel("\(routine.name), \(routine.patternText)")
  }
}

/// Tuning for the cold-launch settle. The "already-alive" launch has no splash:
/// the Library is composed when the icon-zoom lands, then each section rises a
/// few points and fades in on a staggered, raised-cosine breath wave — calm,
/// no overshoot — so the app reads as awake rather than loading. Values dialed
/// in the `docs/plume-launch-already-alive.html` prototype.
private enum LaunchEntrance {
  static let stagger: Double = 0.062        // delay between successive elements
  static let settle: Double = 0.56          // each element's settle duration
  static let rise: CGFloat = 7              // travel distance, before taper
  static let riseTaper: Double = 0.6        // top elements rise less than lower ones
  static let headerRiseFactor: CGFloat = 0.45  // the masthead barely moves — it anchors the zoom
  static let containerScaleFrom: CGFloat = 0.985  // finishes the zoom's deceleration

  /// Symmetric ease approximating the orb's raised-cosine wave (no velocity edges).
  static var curve: Animation { .timingCurve(0.37, 0, 0.63, 1, duration: settle) }
}

private struct LaunchReveal: ViewModifier {
  let index: Int
  let total: Int
  let shown: Bool

  func body(content: Content) -> some View {
    let span = Double(max(total - 1, 1))
    let minFactor = 1 - LaunchEntrance.riseTaper
    var rise = LaunchEntrance.rise * CGFloat(minFactor + (1 - minFactor) * Double(index) / span)
    if index == 0 { rise *= LaunchEntrance.headerRiseFactor }
    return content
      .opacity(shown ? 1 : 0)
      .offset(y: shown ? 0 : rise)
      .animation(LaunchEntrance.curve.delay(Double(index) * LaunchEntrance.stagger), value: shown)
  }
}
