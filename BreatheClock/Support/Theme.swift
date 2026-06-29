import SwiftUI

enum BreatheScheme: String, CaseIterable, Identifiable {
  case charcoal
  case sage
  case indigo

  var id: String { rawValue }

  var name: String {
    switch self {
    case .charcoal: return "Newsprint"
    case .sage: return "Sage"
    case .indigo: return "Evening"
    }
  }

  var mood: String {
    switch self {
    case .charcoal: return "Warm grey"
    case .sage: return "Apothecary"
    case .indigo: return "Dusk"
    }
  }

  var appIconName: String? {
    switch self {
    case .charcoal:
      return nil
    case .sage:
      return "SageAppIcon"
    case .indigo:
      return "IndigoAppIcon"
    }
  }

  var paper: Color {
    switch self {
    case .charcoal: return Color(hex: 0xF1EAD8)
    case .sage: return Color(hex: 0xE7E6D2)
    case .indigo: return Color(hex: 0xE7E0CC)
    }
  }

  var ink: Color {
    switch self {
    case .charcoal: return Color(hex: 0x2E2A25)
    case .sage: return Color(hex: 0x34423A)
    case .indigo: return Color(hex: 0x222D49)
    }
  }

  var accent: Color {
    switch self {
    case .charcoal: return Color(hex: 0xB8533C)
    case .sage: return Color(hex: 0xA6762E)
    // Deepened from 0xC18F3D so the session progress fill is actually
    // perceptible on Evening's cream paper (was ~2.2:1, now ~3.5:1).
    case .indigo: return Color(hex: 0x9C6B27)
    }
  }

  /// Secondary text. Darkened from the original airy greys so the smallest
  /// body copy clears WCAG AA (~4.5:1) on each scheme's paper while still
  /// reading clearly recessed from `ink`.
  var muted: Color {
    switch self {
    case .charcoal: return Color(hex: 0x6E6358)
    case .sage: return Color(hex: 0x586552)
    case .indigo: return Color(hex: 0x595E78)
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
