import SwiftUI

enum BreatheScheme: String, CaseIterable, Identifiable {
  // Four light stocks then one dark, each with its own paper and accent family.
  // Ink clears 10:1 and muted clears 4.5:1 against each scheme's paper.
  // Accents clear 3:1 against both paper and the composited progress track.
  case sepiaClay
  case cochineal
  case celadon
  case coldHarbor
  case indigoVat

  var id: String { rawValue }

  var name: String {
    switch self {
    case .sepiaClay: return "Sepia & Clay"
    case .cochineal: return "Cochineal Lake"
    case .celadon: return "Celadon Glaze"
    case .coldHarbor: return "Cold Harbor"
    case .indigoVat: return "Indigo Vat"
    }
  }

  var mood: String {
    switch self {
    case .sepiaClay: return "Warm oat"
    case .cochineal: return "Slow carmine"
    case .celadon: return "Jade stone"
    case .coldHarbor: return "North daylight"
    case .indigoVat: return "Deep dye"
    }
  }

  /// Dark-field scheme where the orb inverts into a light source (the light
  /// `ink` glows on the dark `paper`). Drives `preferredColorScheme` so the
  /// status bar flips light, and selects the orb numeral
  /// polarity as the sphere fills or dissolves.
  var inverted: Bool {
    self == .indigoVat
  }

  /// Alternate app-icon name per scheme (nil = the primary AppIcon, Sepia & Clay).
  /// Each is a recoloured plume mark from scripts/make_plume_icons.py; the names
  /// must match the .appiconset folders and Info.plist CFBundleAlternateIcons.
  var appIconName: String? {
    switch self {
    case .sepiaClay: return nil
    case .cochineal: return "CochinealAppIcon"
    case .celadon: return "CeladonAppIcon"
    case .coldHarbor: return "ColdHarborAppIcon"
    case .indigoVat: return "IndigoVatAppIcon"
    }
  }

  var paper: Color {
    switch self {
    case .sepiaClay: return Color(hex: 0xF6ECD8)
    case .cochineal: return Color(hex: 0xFBE7E8)
    case .celadon: return Color(hex: 0xE4F0EA)
    case .coldHarbor: return Color(hex: 0xE0ECF0)
    case .indigoVat: return Color(hex: 0x091630)
    }
  }

  var ink: Color {
    switch self {
    case .sepiaClay: return Color(hex: 0x36261C)
    case .cochineal: return Color(hex: 0x391619)
    case .celadon: return Color(hex: 0x112821)
    case .coldHarbor: return Color(hex: 0x1E3548)
    case .indigoVat: return Color(hex: 0xE2ECF7)
    }
  }

  var accent: Color {
    switch self {
    case .sepiaClay: return Color(hex: 0xBC5138)  // terracotta clay
    case .cochineal: return Color(hex: 0xC7404F)  // cochineal carmine
    case .celadon: return Color(hex: 0x008262)    // fired jade
    case .coldHarbor: return Color(hex: 0x007E88) // verdigris teal
    case .indigoVat: return Color(hex: 0xAC8123)  // coppery vat-bloom
    }
  }

  /// Secondary text, tinted to each scheme's temperature and darkened enough to
  /// clear WCAG AA (~4.5:1) on its paper while reading clearly recessed from `ink`.
  var muted: Color {
    switch self {
    case .sepiaClay: return Color(hex: 0x735F4F)
    case .cochineal: return Color(hex: 0x8C595B)
    case .celadon: return Color(hex: 0x546E64)
    case .coldHarbor: return Color(hex: 0x4A6D80)
    case .indigoVat: return Color(hex: 0x8F9DAE)
    }
  }

  var track: Color {
    ink.opacity(0.14)
  }

  var hairline: Color {
    ink.opacity(0.12)
  }
}

extension Color {
  init(hex: UInt, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: opacity
    )
  }
}

enum BreatheFont {
  /// Bundled Fraunces is upright-only: opsz, wght, SOFT and WONK axes,
  /// with real Thin/Light/Regular/SemiBold/Bold named instances. Core Text
  /// applies optical sizing. Do not request an italic the binary doesn't have.
  /// Call sites name their semantic role explicitly; point size is the Large
  /// reference size, never a proxy for the Dynamic Type scaling curve.
  static func display(
    _ size: CGFloat,
    weight: Font.Weight = .regular,
    relativeTo textStyle: Font.TextStyle
  ) -> Font {
    Font.custom(frauncesName(for: weight), size: size, relativeTo: textStyle)
  }

  /// Manrope's bundled wght axis exposes these named instances directly.
  /// Native Dynamic Type remains unrestricted here, including accessibility.
  static func utility(
    _ size: CGFloat,
    weight: Font.Weight = .regular,
    relativeTo textStyle: Font.TextStyle
  ) -> Font {
    Font.custom(manropeName(for: weight), size: size, relativeTo: textStyle)
  }

  private static func frauncesName(for weight: Font.Weight) -> String {
    if weight == .ultraLight || weight == .thin {
      return "Fraunces-Thin"
    }
    if weight == .light {
      return "Fraunces-Light"
    }
    if weight == .semibold {
      return "Fraunces-SemiBold"
    }
    if weight == .bold || weight == .heavy || weight == .black {
      return "Fraunces-Bold"
    }
    return "Fraunces-Regular"
  }

  private static func manropeName(for weight: Font.Weight) -> String {
    if weight == .ultraLight || weight == .thin {
      return "Manrope-ExtraLight"
    }
    if weight == .light {
      return "Manrope-Light"
    }
    if weight == .medium {
      return "Manrope-Medium"
    }
    if weight == .semibold {
      return "Manrope-SemiBold"
    }
    if weight == .bold || weight == .heavy || weight == .black {
      return "Manrope-Bold"
    }
    return "Manrope-Regular"
  }
}

/// Center the rendered line as well as its container, including tracked labels.
/// Keep this on the text itself; a centered outer frame alone is not enough.
struct BreatheButtonText: View {
  let title: String
  let font: Font
  var tracking: CGFloat = 0
  var uppercase = false

  var body: some View {
    Text(title)
      .font(font)
      .tracking(tracking)
      .textCase(uppercase ? .uppercase : nil)
      .multilineTextAlignment(.center)
  }
}

/// A quiet press response without changing layout or the label's weight.
struct BreathePressStyle: ButtonStyle {
  // Muted text has less contrast headroom than ink; its callers skip fading.
  var pressedOpacity: Double = 0.8
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .opacity(configuration.isPressed ? pressedOpacity : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

extension TimeInterval {
  var clockText: String {
    let totalSeconds = max(0, Int(self.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
