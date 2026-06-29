import SwiftUI
import UIKit

struct SettingsView: View {
  let scheme: BreatheScheme
  @Binding var schemeSelection: BreatheScheme
  @Binding var audioCue: AudioCue
  @Binding var hapticsEnabled: Bool
  @Binding var swellHapticsEnabled: Bool
  let onBack: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        topBar
          .padding(.top, 24)
          .padding(.bottom, 26)

        Text("Settings")
          .font(BreatheFont.display(38, weight: .light, italic: true))
          .foregroundStyle(scheme.ink)
          .tracking(-0.7)
          .padding(.bottom, 42)

        settingsSection(title: "Scheme") {
          HStack(spacing: 0) {
            ForEach(Array(BreatheScheme.allCases.enumerated()), id: \.element) { index, option in
              if index > 0 { Spacer(minLength: 12) }
              schemeSwatch(option)
            }
          }
        }

        settingsSection(title: "Audio", topPadding: 48) {
          VStack(spacing: 0) {
            ForEach(AudioCue.allCases) { cue in
              audioRow(cue)
            }
          }
        }

        settingsSection(title: "Haptics", topPadding: 34) {
          HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Breath swell")
                .font(BreatheFont.display(17, weight: .regular))
                .foregroundStyle(scheme.ink)
              Text("Gradual vibration during inhale and exhale")
                .font(BreatheFont.utility(12, weight: .light))
                .foregroundStyle(scheme.muted)
            }

            Spacer()

            Toggle("", isOn: $swellHapticsEnabled)
              .labelsHidden()
              .tint(scheme.ink)
          }
          .padding(.vertical, 5)
          .accessibilityElement(children: .combine)

          HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Phase taps")
                .font(BreatheFont.display(17, weight: .regular))
                .foregroundStyle(scheme.ink)
              Text("Tap at holds, session start, and completion")
                .font(BreatheFont.utility(12, weight: .light))
                .foregroundStyle(scheme.muted)
            }

            Spacer()

            Toggle("", isOn: $hapticsEnabled)
              .labelsHidden()
              .tint(scheme.ink)
          }
          .padding(.vertical, 5)
          .accessibilityElement(children: .combine)
        }

        settingsSection(title: "Safety", topPadding: 34) {
          VStack(alignment: .leading, spacing: 14) {
            Text(BreatheSafety.disclaimer)
              .font(BreatheFont.utility(12, weight: .light))
              .foregroundStyle(scheme.muted)
              .lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
              Text("Take extra care with")
                .font(BreatheFont.utility(10, weight: .medium))
                .foregroundStyle(scheme.muted)
                .tracking(2.4)
                .textCase(.uppercase)
              ForEach(BreatheSafety.contraindications, id: \.self) { item in
                Text("— \(item)")
                  .font(BreatheFont.utility(12, weight: .light))
                  .foregroundStyle(scheme.ink)
              }
            }
          }
        }

        settingsSection(title: "About", topPadding: 34) {
          VStack(spacing: 0) {
            aboutRow("Version", value: "1.0.0")
            aboutRow("Made in", value: "Cambridge")
          }
        }
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 44)
    }
    .background(scheme.paper)
    .scrollIndicators(.hidden)
    .animation(.easeInOut(duration: 0.4), value: scheme.id)
  }

  private var topBar: some View {
    HStack {
      Button(action: onBack) {
        HStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 12, weight: .semibold))
          Text("Back")
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
    }
  }

  private func settingsSection<Content: View>(
    title: String,
    topPadding: CGFloat = 0,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(BreatheFont.utility(10, weight: .medium))
        .foregroundStyle(scheme.muted)
        .tracking(3.1)
        .textCase(.uppercase)

      content()
    }
    .padding(.top, topPadding)
  }

  private func audioRow(_ cue: AudioCue) -> some View {
    Button {
      audioCue = cue
      if cue != .off {
        AudioCuePlayer.shared.playBoxPreview(cue)
      }
    } label: {
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 3) {
          Text(cue.title)
            .font(BreatheFont.display(17, weight: cue == audioCue ? .semibold : .regular))
            .foregroundStyle(scheme.ink)

          if let detail = cue.detail {
            Text(detail)
              .font(BreatheFont.display(13, weight: .light, italic: true))
              .foregroundStyle(scheme.muted)
          }
        }

        Spacer()

        if cue == audioCue {
          Circle()
            .fill(scheme.ink)
            .frame(width: 8, height: 8)
        }
      }
      .padding(.vertical, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(scheme.hairline)
        .frame(height: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(cue == audioCue ? .isSelected : [])
  }

  private func aboutRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(BreatheFont.utility(13, weight: .regular))
        .foregroundStyle(scheme.muted)
      Spacer()
      Text(value)
        .font(BreatheFont.display(14, weight: .regular, italic: true))
        .foregroundStyle(scheme.ink)
    }
    .padding(.vertical, 13)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(scheme.hairline)
        .frame(height: 1)
    }
  }

  /// A true preview of the scheme — its warm paper, its ink, and a tick of its
  /// accent — with the scheme's name beneath, so the choice is legible without
  /// relying on telling three near-black dots apart.
  private func schemeSwatch(_ option: BreatheScheme) -> some View {
    let isSelected = option == schemeSelection
    return Button {
      schemeSelection = option
      updateAppIcon(for: option)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        ZStack {
          Circle()
            .fill(option.paper)
            .frame(width: 40, height: 40)
            .overlay(Circle().stroke(scheme.ink.opacity(0.18), lineWidth: 1))
          Circle()
            .fill(option.ink)
            .frame(width: 21, height: 21)
          Circle()
            .fill(option.accent)
            .frame(width: 8, height: 8)
            .offset(x: 11, y: 10)
        }
        .frame(width: 44, height: 44)
        .overlay {
          if isSelected {
            Circle()
              .stroke(scheme.ink, lineWidth: 1.5)
              .frame(width: 44, height: 44)
          }
        }
        .contentShape(Rectangle())

        Text(option.name)
          .font(BreatheFont.utility(10, weight: isSelected ? .semibold : .medium))
          .foregroundStyle(isSelected ? scheme.ink : scheme.muted)
          .tracking(1.4)
          .textCase(.uppercase)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(option.name)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func updateAppIcon(for scheme: BreatheScheme) {
    guard UIApplication.shared.supportsAlternateIcons else { return }
    guard UIApplication.shared.alternateIconName != scheme.appIconName else { return }
    UIApplication.shared.setAlternateIconName(scheme.appIconName) { error in
      if let error {
        print("Could not update app icon: \(error.localizedDescription)")
      }
    }
  }
}
