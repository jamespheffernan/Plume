import SwiftUI

struct LibraryView: View {
  let scheme: BreatheScheme
  let selectedRoutine: Routine
  let focusedCategory: String?
  let onSelectRoutine: (Routine) -> Void
  let onShowAll: () -> Void
  let onGoals: () -> Void
  let onSettings: () -> Void

  private var groups: [(category: String, routines: [Routine])] {
    guard let focusedCategory else { return Routine.grouped }
    return Routine.grouped.filter { $0.category == focusedCategory }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
          .padding(.horizontal, 28)
          .padding(.top, 24)
          .padding(.bottom, 20)

        if focusedCategory != nil {
          filterBar
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
        }

        Rectangle()
          .fill(scheme.hairline)
          .frame(height: 1)
          .padding(.horizontal, 28)
          .padding(.bottom, 22)

        VStack(alignment: .leading, spacing: 28) {
          ForEach(groups, id: \.category) { group in
            categorySection(group)
          }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 44)
      }
    }
    .background(scheme.paper)
    .scrollIndicators(.hidden)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
    .animation(.easeInOut(duration: 0.3), value: focusedCategory)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Button(action: onGoals) {
          HStack(spacing: 8) {
            Image(systemName: "chevron.left")
              .font(.system(size: 12, weight: .semibold))
            Text("Goals")
              .font(BreatheFont.utility(12, weight: .regular))
              .tracking(2.1)
          }
          .textCase(.uppercase)
          .foregroundStyle(scheme.muted)
          .frame(height: 44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

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

      Text(focusedCategory ?? "All practices")
        .font(BreatheFont.display(30, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .tracking(-0.5)
    }
  }

  private var filterBar: some View {
    HStack {
      Text("Filtered by goal")
        .font(BreatheFont.utility(11, weight: .light))
        .foregroundStyle(scheme.muted)
        .tracking(2.2)
        .textCase(.uppercase)

      Spacer()

      Button(action: onShowAll) {
        Text("Show all")
          .font(BreatheFont.utility(11, weight: .medium))
          .foregroundStyle(scheme.ink)
          .tracking(2.2)
          .textCase(.uppercase)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private func categorySection(_ group: (category: String, routines: [Routine])) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(group.category)
        .font(BreatheFont.display(14, weight: .regular, italic: true))
        .foregroundStyle(scheme.muted)
        .tracking(0.4)

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
