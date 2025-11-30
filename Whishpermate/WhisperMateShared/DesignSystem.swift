import SwiftUI

// MARK: - Design System

// Minimal design system using standard macOS colors
// Primary/Accent color is set via AccentColor.colorset in Assets

// MARK: - Button Styles

/// Primary button with accent color background
public struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsFont(.bodySemibold)
            .foregroundStyle(.white)
            .background(Capsule().fill(Color.accentColor))
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

// MARK: - Compatibility Aliases

// These map old ds* colors to standard macOS colors for gradual migration

public extension Color {
    // Background & Foreground
    static var dsBackground: Color { Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) } // #ffffff
    static var dsForeground: Color { Color(nsColor: NSColor(red: 0x11 / 255.0, green: 0x18 / 255.0, blue: 0x27 / 255.0, alpha: 1)) } // #111827

    // Primary
    static var dsPrimary: Color { .accentColor } // #d87943 via AccentColor asset
    static var dsPrimaryForeground: Color { .white } // #ffffff

    // Secondary
    static var dsSecondary: Color { Color(nsColor: NSColor(red: 0x52 / 255.0, green: 0x75 / 255.0, blue: 0x75 / 255.0, alpha: 1)) } // #527575
    static var dsSecondaryForeground: Color { .white } // #ffffff

    // Accent
    static var dsAccent: Color { Color(nsColor: NSColor(red: 0xEE / 255.0, green: 0xEE / 255.0, blue: 0xEE / 255.0, alpha: 1)) } // #eeeeee
    static var dsAccentForeground: Color { Color(nsColor: NSColor(red: 0x11 / 255.0, green: 0x18 / 255.0, blue: 0x27 / 255.0, alpha: 1)) } // #111827

    // Card
    static var dsCard: Color { Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) } // #ffffff
    static var dsCardForeground: Color { Color(nsColor: NSColor(red: 0x11 / 255.0, green: 0x18 / 255.0, blue: 0x27 / 255.0, alpha: 1)) } // #111827

    // Muted
    static var dsMuted: Color { Color(nsColor: NSColor(red: 0xF3 / 255.0, green: 0xF4 / 255.0, blue: 0xF6 / 255.0, alpha: 1)) } // #f3f4f6
    static var dsMutedForeground: Color { Color(nsColor: NSColor(red: 0x6B / 255.0, green: 0x72 / 255.0, blue: 0x80 / 255.0, alpha: 1)) } // #6b7280

    // Border, Input, Ring
    static var dsBorder: Color { Color(nsColor: NSColor(red: 0xE5 / 255.0, green: 0xE7 / 255.0, blue: 0xEB / 255.0, alpha: 1)) } // #e5e7eb
    static var dsInput: Color { Color(nsColor: NSColor(red: 0xE5 / 255.0, green: 0xE7 / 255.0, blue: 0xEB / 255.0, alpha: 1)) } // #e5e7eb
    static var dsRing: Color { .accentColor } // #d87943

    // Destructive
    static var dsDestructive: Color { Color(nsColor: NSColor(red: 0xEF / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0, alpha: 1)) } // #ef4444
    static var dsDestructiveForeground: Color { Color(nsColor: NSColor(red: 0xFA / 255.0, green: 0xFA / 255.0, blue: 0xFA / 255.0, alpha: 1)) } // #fafafa

    // Sidebar
    static var dsSidebarBackground: Color { Color(nsColor: NSColor(red: 0xF3 / 255.0, green: 0xF4 / 255.0, blue: 0xF6 / 255.0, alpha: 1)) } // #f3f4f6
    static var dsSidebarForeground: Color { Color(nsColor: NSColor(red: 0x11 / 255.0, green: 0x18 / 255.0, blue: 0x27 / 255.0, alpha: 1)) } // #111827
    static var dsSidebarPrimary: Color { .accentColor } // #d87943
    static var dsSidebarAccent: Color { Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) } // #ffffff
    static var dsSidebarBorder: Color { Color(nsColor: NSColor(red: 0xE5 / 255.0, green: 0xE7 / 255.0, blue: 0xEB / 255.0, alpha: 1)) } // #e5e7eb

    // Charts
    static var dsChart1: Color { Color(nsColor: NSColor(red: 0x5F / 255.0, green: 0x87 / 255.0, blue: 0x87 / 255.0, alpha: 1)) } // #5f8787
    static var dsChart2: Color { Color(nsColor: NSColor(red: 0xE7 / 255.0, green: 0x8A / 255.0, blue: 0x53 / 255.0, alpha: 1)) } // #e78a53
    static var dsChart3: Color { Color(nsColor: NSColor(red: 0xFB / 255.0, green: 0xCB / 255.0, blue: 0x97 / 255.0, alpha: 1)) } // #fbcb97

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
        LinearGradient(colors: [.accentColor, .accentColor], startPoint: .leading, endPoint: .trailing)
    }

    static func dsSecondaryGradient(for _: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.dsSecondary, Color.dsSecondary], startPoint: .leading, endPoint: .trailing)
    }
}
