import SwiftUI

/// Goal-first entry screen. The capsule's first design rule is "start from the
/// state goal, not the technique name." Each card maps to an outcome category.
struct GoalEntryView: View {
  let scheme: BreatheScheme
  let onChooseCategory: (String) -> Void
  let onBrowseAll: () -> Void
  let onSettings: () -> Void

  private struct Goal: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let category: String
  }

  private let goals: [Goal] = [
    Goal(title: "Calm", subtitle: "Settle anxiety and wind down for sleep", category: "Calm"),
    Goal(title: "Focus", subtitle: "Steady rhythm for clear, composed attention", category: "Focus"),
    Goal(title: "Energize", subtitle: "Brisk breath to lift alertness before effort", category: "Energize"),
    Goal(title: "Go inward", subtitle: "Humming, alternate nostril, guided stillness", category: "Contemplative"),
    Goal(title: "Train", subtitle: "Build CO2 tolerance and measure your BOLT", category: "Train"),
    Goal(title: "Release", subtitle: "Connected breathing to surface and let go", category: "Release")
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
          .padding(.horizontal, 28)
          .padding(.top, 28)
          .padding(.bottom, 30)

        VStack(spacing: 12) {
          ForEach(goals) { goal in
            goalCard(goal)
          }
        }
        .padding(.horizontal, 24)

        Button(action: onBrowseAll) {
          Text("Browse all practices")
            .font(BreatheFont.utility(11, weight: .medium))
            .foregroundStyle(scheme.muted)
            .tracking(3)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 30)
      }
    }
    .background(scheme.paper)
    .scrollIndicators(.hidden)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center) {
        Text("Plume")
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

      Text("What do you need\nright now?")
        .font(BreatheFont.display(34, weight: .light, italic: true))
        .foregroundStyle(scheme.ink)
        .tracking(-0.6)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func goalCard(_ goal: Goal) -> some View {
    Button {
      onChooseCategory(goal.category)
    } label: {
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Text(goal.title)
            .font(BreatheFont.display(26, weight: .regular, italic: true))
            .foregroundStyle(scheme.ink)

          Text(goal.subtitle)
            .font(BreatheFont.utility(12, weight: .light))
            .foregroundStyle(scheme.muted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 10)

        Image(systemName: "arrow.right")
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(scheme.muted)
      }
      .padding(.vertical, 20)
      .padding(.horizontal, 22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(scheme.hairline, lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(goal.title). \(goal.subtitle)")
  }
}
