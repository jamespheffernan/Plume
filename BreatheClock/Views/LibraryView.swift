import SwiftUI

struct LibraryView: View {
  let scheme: BreatheScheme
  let selectedRoutine: Routine
  let onSelectRoutine: (Routine) -> Void
  let onSettings: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
          .padding(.horizontal, 28)
          .padding(.top, 28)
          .padding(.bottom, 26)

        Rectangle()
          .fill(scheme.hairline)
          .frame(height: 1)
          .padding(.horizontal, 28)
          .padding(.bottom, 22)

        VStack(alignment: .leading, spacing: 28) {
          ForEach(Routine.grouped, id: \.category) { group in
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
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text("Breathe")
        .font(BreatheFont.display(28, weight: .regular, italic: true))
        .foregroundStyle(scheme.ink)
        .tracking(-0.2)

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
