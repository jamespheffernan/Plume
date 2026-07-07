import SwiftUI

enum BreatheScheme: String, CaseIterable, Identifiable {
  // Four light stocks then one dark. Every scheme is a distinct paper *and*
  // accent hue-family (not the old three-creams-with-brown), each verified to
  // clear ink ≥10:1, muted ≥4.5:1, accent ≥3:1 on its own paper.
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
  /// status bar flips light, and it is why the orb numeral crossfades to
  /// `paper` rather than white — `paper` reads on both a dark and a light orb.
  var inverted: Bool {
    self == .indigoVat
  }

  var appIconName: String? {
    // No alternate-icon assets exist for these schemes yet; nil resets to the
    // primary icon. (The old Sage/Indigo icon assets are now dormant.)
    nil
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
    case .sepiaClay: return Color(hex: 0xC2563D)  // terracotta clay
    case .cochineal: return Color(hex: 0xD24B58)  // cochineal carmine
    case .celadon: return Color(hex: 0x219271)    // fired jade
    case .coldHarbor: return Color(hex: 0x17919C) // verdigris teal
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
  /// Fraunces display face. Scales with Dynamic Type: the fixed `size` is the
  /// reference point at the Large (default) content size, and growth follows
  /// `textStyle`'s ramp. Pass `relativeTo:` to override the inferred style;
  /// the default maps `size` to the text style whose own default size is
  /// closest, so each call site grows along a sensible curve.
  static func display(
    _ size: CGFloat,
    weight: Font.Weight = .regular,
    italic: Bool = false,
    relativeTo textStyle: Font.TextStyle? = nil
  ) -> Font {
    let font = Font.custom(frauncesName(for: weight), size: size, relativeTo: textStyle ?? scaleStyle(for: size))
    return italic ? font.italic() : font
  }

  /// Manrope utility face. Scales with Dynamic Type — see `display(_:)`.
  static func utility(
    _ size: CGFloat,
    weight: Font.Weight = .regular,
    relativeTo textStyle: Font.TextStyle? = nil
  ) -> Font {
    Font.custom(manropeName(for: weight), size: size, relativeTo: textStyle ?? scaleStyle(for: size))
  }

  /// Picks the Dynamic Type text style whose default point size is nearest the
  /// given fixed size, so `relativeTo:` scaling follows a curve matched to the
  /// role: tiny tracked labels grow aggressively, hero titles grow gently.
  private static func scaleStyle(for size: CGFloat) -> Font.TextStyle {
    switch size {
    case ..<11.5: return .caption2     // 11
    case ..<12.5: return .caption      // 12
    case ..<14: return .footnote       // 13
    case ..<15.5: return .subheadline  // 15
    case ..<16.5: return .callout      // 16
    case ..<18.5: return .body         // 17
    case ..<21: return .title3         // 20
    case ..<25: return .title2         // 22
    case ..<31: return .title          // 28
    default: return .largeTitle        // 34
    }
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

extension TimeInterval {
  var clockText: String {
    let totalSeconds = max(0, Int(self.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
