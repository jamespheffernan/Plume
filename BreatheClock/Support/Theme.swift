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
    case .indigo: return Color(hex: 0xC18F3D)
    }
  }

  var muted: Color {
    switch self {
    case .charcoal: return Color(hex: 0x7A6F64)
    case .sage: return Color(hex: 0x73806F)
    case .indigo: return Color(hex: 0x6A6F88)
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
  static func display(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
    let font = Font.custom(frauncesName(for: weight), size: size)
    return italic ? font.italic() : font
  }

  static func utility(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    Font.custom(manropeName(for: weight), size: size)
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
