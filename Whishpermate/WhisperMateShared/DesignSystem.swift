import SwiftUI

// MARK: - Design System

// Minimal design system using standard macOS colors
// Primary/Accent color is set via AccentColor.colorset in Assets

// MARK: - Button Styles

/// Primary button with orange background
public struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsFont(.title3)
            .foregroundStyle(Color.dsPrimaryForeground)
            .background(Capsule().fill(Color.dsPrimary))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary button with border
public struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsFont(.bodyMedium)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .background(Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Corner Radius Constants

public enum DSCornerRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let extraLarge: CGFloat = 24
}

// MARK: - Font Names

public enum DSFontName {
    public static let geist = "Geist"
    public static let geistMono = "GeistMono"
    public static let jetBrainsMono = "JetBrainsMono"
}

// MARK: - Typography

public enum DSTypography {
    // Matches macOS system font sizes
    case iconLarge // 64pt - for large icons/display
    case largeTitle // 26pt bold - .largeTitle
    case title // 22pt bold - .title
    case title2 // 17pt bold - .title2
    case title3 // 15pt semibold - .title3
    case headline // 13pt semibold - .headline
    case subheadline // 11pt regular - .subheadline
    case body // 13pt regular - .body
    case callout // 12pt regular - .callout
    case footnote // 10pt regular - .footnote
    case caption // 10pt regular - .caption
    case caption2 // 10pt regular - .caption2

    // Custom styles
    case h1 // 48pt bold
    case h2 // 36pt bold
    case h3 // 28pt bold
    case h4 // 22pt semibold
    case h5 // 17pt semibold
    case bodyMedium // 13pt medium
    case bodySemibold // 13pt semibold
    case captionMedium // 10pt medium
    case captionSemibold // 10pt semibold
    case label // 11pt regular
    case labelMedium // 11pt medium
    case small // 10pt regular
    case smallMedium // 10pt medium
    case tiny // 11pt regular
    case tinyBold // 11pt bold
    case micro // 9pt regular
    case microBold // 9pt bold

    // Monospace (JetBrains Mono)
    case mono // 13pt mono
    case monoSmall // 11pt mono

    public var font: Font {
        switch self {
        // System-matching sizes
        case .iconLarge: return DSFont.font(size: 64, weight: .regular)
        case .largeTitle: return DSFont.font(size: 26, weight: .bold)
        case .title: return DSFont.font(size: 22, weight: .bold)
        case .title2: return DSFont.font(size: 17, weight: .bold)
        case .title3: return DSFont.font(size: 15, weight: .semibold)
        case .headline: return DSFont.font(size: 13, weight: .semibold)
        case .subheadline: return DSFont.font(size: 11, weight: .regular)
        case .body: return DSFont.font(size: 13, weight: .regular)
        case .callout: return DSFont.font(size: 12, weight: .regular)
        case .footnote: return DSFont.font(size: 10, weight: .regular)
        case .caption: return DSFont.font(size: 10, weight: .regular)
        case .caption2: return DSFont.font(size: 10, weight: .regular)
        // Custom sizes
        case .h1: return DSFont.font(size: 48, weight: .bold)
        case .h2: return DSFont.font(size: 36, weight: .bold)
        case .h3: return DSFont.font(size: 28, weight: .bold)
        case .h4: return DSFont.font(size: 22, weight: .semibold)
        case .h5: return DSFont.font(size: 17, weight: .semibold)
        case .bodyMedium: return DSFont.font(size: 13, weight: .medium)
        case .bodySemibold: return DSFont.font(size: 13, weight: .semibold)
        case .captionMedium: return DSFont.font(size: 10, weight: .medium)
        case .captionSemibold: return DSFont.font(size: 10, weight: .semibold)
        case .label: return DSFont.font(size: 11, weight: .regular)
        case .labelMedium: return DSFont.font(size: 11, weight: .medium)
        case .small: return DSFont.font(size: 10, weight: .regular)
        case .smallMedium: return DSFont.font(size: 10, weight: .medium)
        case .tiny: return DSFont.font(size: 11, weight: .regular)
        case .tinyBold: return DSFont.font(size: 11, weight: .bold)
        case .micro: return DSFont.font(size: 9, weight: .regular)
        case .microBold: return DSFont.font(size: 9, weight: .bold)
        case .mono: return DSFont.monoFont(size: 13, weight: .regular)
        case .monoSmall: return DSFont.monoFont(size: 11, weight: .regular)
        }
    }
}

// MARK: - Font Helper

public enum DSFont {
    /// Returns system font
    public static func font(size: CGFloat, weight: Font.Weight) -> Font {
        return .system(size: size, weight: weight)
    }

    /// Returns system monospace font
    public static func monoFont(size: CGFloat, weight: Font.Weight) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Font Extension for easy replacement of .system()

public extension Font {
    /// System font - alias for consistency
    static func geist(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }

    /// System monospace font
    static func jetBrainsMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

public extension View {
    func dsFont(_ style: DSTypography) -> some View {
        font(style.font)
    }
}

// MARK: - Shadow

public enum DSShadow {
    case soft, medium

    public var radius: CGFloat {
        switch self {
        case .soft: return 4
        case .medium: return 8
        }
    }

    public var opacity: Double {
        switch self {
        case .soft: return 0.05
        case .medium: return 0.1
        }
    }

    public var y: CGFloat {
        switch self {
        case .soft: return 2
        case .medium: return 4
        }
    }
}

public extension View {
    func dsShadow(_ style: DSShadow) -> some View {
        shadow(color: Color.black.opacity(style.opacity), radius: style.radius, y: style.y)
    }
}

// MARK: - Color Palette

// Orange/Blue theme with clean, modern look

public extension Color {
    // Background & Foreground
    static var dsBackground: Color { Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) } // #FFFFFF
    static var dsForeground: Color { Color(nsColor: NSColor(red: 0, green: 0, blue: 0, alpha: 1)) } // #000000

    // Primary (Orange)
    static var dsPrimary: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #FF6600
    static var dsPrimaryForeground: Color { .white } // #FFFFFF

    // Secondary (Blue)
    static var dsSecondary: Color { Color(nsColor: NSColor(red: 0x00 / 255.0, green: 0x7B / 255.0, blue: 0xFF / 255.0, alpha: 1)) } // #007BFF
    static var dsSecondaryForeground: Color { .white } // #FFFFFF

    // Accent (Light Orange)
    static var dsAccent: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0xD2 / 255.0, blue: 0xA8 / 255.0, alpha: 1)) } // #FFD2A8
    static var dsAccentForeground: Color { Color(nsColor: NSColor(red: 0, green: 0, blue: 0, alpha: 1)) } // #000000

    // Card
    static var dsCard: Color { Color(nsColor: NSColor(red: 0xFD / 255.0, green: 0xFD / 255.0, blue: 0xFD / 255.0, alpha: 1)) } // #FDFDFD
    static var dsCardForeground: Color { Color(nsColor: NSColor(red: 0, green: 0, blue: 0, alpha: 1)) } // #000000

    // Popover
    static var dsPopover: Color { Color(nsColor: NSColor(red: 0xFD / 255.0, green: 0xFD / 255.0, blue: 0xFD / 255.0, alpha: 1)) } // #FDFDFD
    static var dsPopoverForeground: Color { Color(nsColor: NSColor(red: 0, green: 0, blue: 0, alpha: 1)) } // #000000

    // Muted
    static var dsMuted: Color { Color(nsColor: NSColor(red: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF5 / 255.0, alpha: 1)) } // #F5F5F5
    static var dsMutedForeground: Color { Color(nsColor: NSColor(red: 0x4A / 255.0, green: 0x4A / 255.0, blue: 0x4A / 255.0, alpha: 1)) } // #4A4A4A

    // Border, Input, Ring
    static var dsBorder: Color { Color(nsColor: NSColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xCC / 255.0, alpha: 1)) } // #CCCCCC
    static var dsInput: Color { Color(nsColor: NSColor(red: 0xE0 / 255.0, green: 0xE0 / 255.0, blue: 0xE0 / 255.0, alpha: 1)) } // #E0E0E0
    static var dsRing: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #FF6600

    // Destructive
    static var dsDestructive: Color { Color(nsColor: NSColor(red: 0xDC / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0, alpha: 1)) } // #DC2626
    static var dsDestructiveForeground: Color { .white } // #FFFFFF

    // Sidebar (Orange theme)
    static var dsSidebarBackground: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #FF6600
    static var dsSidebarForeground: Color { .white } // #FFFFFF
    static var dsSidebarPrimary: Color { Color(nsColor: NSColor(red: 0xE6 / 255.0, green: 0x5C / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #E65C00
    static var dsSidebarPrimaryForeground: Color { .white } // #FFFFFF
    static var dsSidebarAccent: Color { Color(nsColor: NSColor(red: 0x00 / 255.0, green: 0x7B / 255.0, blue: 0xFF / 255.0, alpha: 1)) } // #007BFF
    static var dsSidebarAccentForeground: Color { .white } // #FFFFFF
    static var dsSidebarBorder: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x7A / 255.0, blue: 0x1A / 255.0, alpha: 1)) } // #FF7A1A
    static var dsSidebarRing: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #FF6600

    // Charts
    static var dsChart1: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x00 / 255.0, alpha: 1)) } // #FF6600
    static var dsChart2: Color { Color(nsColor: NSColor(red: 0x00 / 255.0, green: 0x7B / 255.0, blue: 0xFF / 255.0, alpha: 1)) } // #007BFF
    static var dsChart3: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0xD2 / 255.0, blue: 0xA8 / 255.0, alpha: 1)) } // #FFD2A8
    static var dsChart4: Color { Color(nsColor: NSColor(red: 0xB0 / 255.0, green: 0xD8 / 255.0, blue: 0xFF / 255.0, alpha: 1)) } // #B0D8FF
    static var dsChart5: Color { Color(nsColor: NSColor(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x66 / 255.0, alpha: 1)) } // #FF9F66

    // Legacy adaptive functions
    static func dsBackgroundAdaptive(for _: ColorScheme) -> Color { dsBackground }
    static func dsForegroundAdaptive(for _: ColorScheme) -> Color { dsForeground }
    static func dsPrimaryAdaptive(for _: ColorScheme) -> Color { dsPrimary }
    static func dsPrimaryGlowAdaptive(for _: ColorScheme) -> Color { dsPrimary }
    static func dsSecondaryAdaptive(for _: ColorScheme) -> Color { dsSecondary }
    static func dsAccentAdaptive(for _: ColorScheme) -> Color { dsAccent }
    static func dsMutedAdaptive(for _: ColorScheme) -> Color { dsMuted }
    static func dsMutedForegroundAdaptive(for _: ColorScheme) -> Color { dsMutedForeground }
    static func dsBorderAdaptive(for _: ColorScheme) -> Color { dsBorder }
    static func dsCardAdaptive(for _: ColorScheme) -> Color { dsCard }
}

// MARK: - View Modifiers

public struct DSCardStyle: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var hasShadow: Bool = true

    public init(cornerRadius: CGFloat = 12, hasShadow: Bool = true) {
        self.cornerRadius = cornerRadius
        self.hasShadow = hasShadow
    }

    public func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            .shadow(color: hasShadow ? Color.black.opacity(0.05) : .clear, radius: 8, y: 4)
    }
}

public struct GlassBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content.background(.ultraThinMaterial)
    }
}

public extension View {
    func dsCardStyle(cornerRadius: CGFloat = 12, hasShadow: Bool = true) -> some View {
        modifier(DSCardStyle(cornerRadius: cornerRadius, hasShadow: hasShadow))
    }

    func dsGlassBackground() -> some View {
        modifier(GlassBackground())
    }
}

// MARK: - Gradient Definitions

public extension LinearGradient {
    static func dsPrimaryGradient(for _: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.dsPrimary, Color.dsChart5], startPoint: .leading, endPoint: .trailing)
    }

    static func dsSecondaryGradient(for _: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.dsSecondary, Color.dsChart4], startPoint: .leading, endPoint: .trailing)
    }
}
