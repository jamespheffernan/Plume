import SwiftUI

struct LibraryView: View {
  let scheme: BreatheScheme
  let selectedRoutine: Routine
  let onSelectRoutine: (Routine) -> Void
  let onSettings: () -> Void

  @State private var selectedCategory: String?

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
      header
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 18)

      pillRow
        .padding(.bottom, 18)

      Rectangle()
        .fill(scheme.hairline)
        .frame(height: 1)
        .padding(.horizontal, 28)

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          ForEach(groups, id: \.category) { group in
            categorySection(group, showLabel: selectedCategory == nil)
          }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 44)
      }
      .scrollIndicators(.hidden)
    }
    .background(scheme.paper)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
    .animation(.easeInOut(duration: 0.28), value: selectedCategory)
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
    showLabel: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      if showLabel {
        Text(group.category)
          .font(BreatheFont.display(14, weight: .regular, italic: true))
          .foregroundStyle(scheme.muted)
          .tracking(0.4)
      }

      VStack(spacing: 0) {
        ForEach(group.routines) { routine in
          routineRow(routine)
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
