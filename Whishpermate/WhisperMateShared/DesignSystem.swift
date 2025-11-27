import SwiftUI

// MARK: - Design System
// Custom design system with light/dark mode support

// MARK: - Color Definitions
// Primary Theme Colors:
// - Background: #ffffff, Foreground: #111827
// - Primary: #d87943 (orange/terracotta), Primary Foreground: #ffffff
// - Secondary: #527575 (teal), Secondary Foreground: #ffffff
// - Accent: #eeeeee, Accent Foreground: #111827
// - Muted: #f3f4f6, Muted Foreground: #6b7280
// - Border: #e5e7eb, Card: #ffffff
// - Destructive: #ef4444, Ring: #d87943

extension Color {
    // Background colors
    static var dsBackground: Color {
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) // #ffffff
    }

    static var dsForeground: Color {
        Color(nsColor: NSColor(red: 0x11/255.0, green: 0x18/255.0, blue: 0x27/255.0, alpha: 1)) // #111827
    }

    // Primary colors - terracotta/orange
    static var dsPrimary: Color {
        Color(nsColor: NSColor(red: 0xD8/255.0, green: 0x79/255.0, blue: 0x43/255.0, alpha: 1)) // #d87943
    }

    static var dsPrimaryForeground: Color {
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) // #ffffff
    }

    // Secondary - teal
    static var dsSecondary: Color {
        Color(nsColor: NSColor(red: 0x52/255.0, green: 0x75/255.0, blue: 0x75/255.0, alpha: 1)) // #527575
    }

    static var dsSecondaryForeground: Color {
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) // #ffffff
    }

    // Accent
    static var dsAccent: Color {
        Color(nsColor: NSColor(red: 0xEE/255.0, green: 0xEE/255.0, blue: 0xEE/255.0, alpha: 1)) // #eeeeee
    }

    static var dsAccentForeground: Color {
        Color(nsColor: NSColor(red: 0x11/255.0, green: 0x18/255.0, blue: 0x27/255.0, alpha: 1)) // #111827
    }

    // Muted colors
    static var dsMuted: Color {
        Color(nsColor: NSColor(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF6/255.0, alpha: 1)) // #f3f4f6
    }

    static var dsMutedForeground: Color {
        Color(nsColor: NSColor(red: 0x6B/255.0, green: 0x72/255.0, blue: 0x80/255.0, alpha: 1)) // #6b7280
    }

    // Border and card
    static var dsBorder: Color {
        Color(nsColor: NSColor(red: 0xE5/255.0, green: 0xE7/255.0, blue: 0xEB/255.0, alpha: 1)) // #e5e7eb
    }

    static var dsCard: Color {
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) // #ffffff
    }

    static var dsCardForeground: Color {
        Color(nsColor: NSColor(red: 0x11/255.0, green: 0x18/255.0, blue: 0x27/255.0, alpha: 1)) // #111827
    }

    // Input and Ring
    static var dsInput: Color {
        Color(nsColor: NSColor(red: 0xE5/255.0, green: 0xE7/255.0, blue: 0xEB/255.0, alpha: 1)) // #e5e7eb
    }

    static var dsRing: Color {
        Color(nsColor: NSColor(red: 0xD8/255.0, green: 0x79/255.0, blue: 0x43/255.0, alpha: 1)) // #d87943
    }

    // Destructive
    static var dsDestructive: Color {
        Color(nsColor: NSColor(red: 0xEF/255.0, green: 0x44/255.0, blue: 0x44/255.0, alpha: 1)) // #ef4444
    }

    static var dsDestructiveForeground: Color {
        Color(nsColor: NSColor(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0, alpha: 1)) // #fafafa
    }

    // Sidebar colors
    static var dsSidebarBackground: Color {
        Color(nsColor: NSColor(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF6/255.0, alpha: 1)) // #f3f4f6
    }

    static var dsSidebarForeground: Color {
        Color(nsColor: NSColor(red: 0x11/255.0, green: 0x18/255.0, blue: 0x27/255.0, alpha: 1)) // #111827
    }

    static var dsSidebarPrimary: Color {
        Color(nsColor: NSColor(red: 0xD8/255.0, green: 0x79/255.0, blue: 0x43/255.0, alpha: 1)) // #d87943
    }

    static var dsSidebarAccent: Color {
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)) // #ffffff
    }

    static var dsSidebarBorder: Color {
        Color(nsColor: NSColor(red: 0xE5/255.0, green: 0xE7/255.0, blue: 0xEB/255.0, alpha: 1)) // #e5e7eb
    }

    // Chart colors
    static var dsChart1: Color {
        Color(nsColor: NSColor(red: 0x5F/255.0, green: 0x87/255.0, blue: 0x87/255.0, alpha: 1)) // #5f8787
    }

    static var dsChart2: Color {
        Color(nsColor: NSColor(red: 0xE7/255.0, green: 0x8A/255.0, blue: 0x53/255.0, alpha: 1)) // #e78a53
    }

    static var dsChart3: Color {
        Color(nsColor: NSColor(red: 0xFB/255.0, green: 0xCB/255.0, blue: 0x97/255.0, alpha: 1)) // #fbcb97
    }
}

// MARK: - Legacy Adaptive Colors (for compatibility)
extension Color {
    static func dsBackgroundAdaptive(for colorScheme: ColorScheme) -> Color { dsBackground }
    static func dsForegroundAdaptive(for colorScheme: ColorScheme) -> Color { dsForeground }
    static func dsPrimaryAdaptive(for colorScheme: ColorScheme) -> Color { dsPrimary }
    static func dsPrimaryGlowAdaptive(for colorScheme: ColorScheme) -> Color { dsPrimary }
    static func dsSecondaryAdaptive(for colorScheme: ColorScheme) -> Color { dsSecondary }
    static func dsAccentAdaptive(for colorScheme: ColorScheme) -> Color { dsAccent }
    static func dsMutedAdaptive(for colorScheme: ColorScheme) -> Color { dsMuted }
    static func dsMutedForegroundAdaptive(for colorScheme: ColorScheme) -> Color { dsMutedForeground }
    static func dsBorderAdaptive(for colorScheme: ColorScheme) -> Color { dsBorder }
    static func dsCardAdaptive(for colorScheme: ColorScheme) -> Color { dsCard }
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design System View Modifiers

// Glass effect background
struct GlassBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.dsCardAdaptive(for: colorScheme).opacity(0.7))
    }
}

// Card style
struct DSCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 12
    var hasShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.dsCardAdaptive(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.dsBorderAdaptive(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: hasShadow ? Color.black.opacity(0.05) : .clear, radius: 8, y: 4)
    }
}

// Primary button style - terracotta/orange solid background
struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.dsPrimaryForeground)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.dsPrimary)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Secondary button style - teal outline
struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.dsSecondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func dsCardStyle(cornerRadius: CGFloat = 12, hasShadow: Bool = true) -> some View {
        modifier(DSCardStyle(cornerRadius: cornerRadius, hasShadow: hasShadow))
    }

    func dsGlassBackground() -> some View {
        modifier(GlassBackground())
    }
}

// MARK: - Design System Constants

enum DSCornerRadius {
    static let small: CGFloat = 8      // rounded-lg
    static let medium: CGFloat = 12    // rounded-xl
    static let large: CGFloat = 16     // rounded-2xl
    static let extraLarge: CGFloat = 24 // rounded-3xl
}

enum DSShadow {
    case soft
    case medium

    var radius: CGFloat {
        switch self {
        case .soft: return 4
        case .medium: return 8
        }
    }

    var opacity: Double {
        switch self {
        case .soft: return 0.05
        case .medium: return 0.1
        }
    }

    var y: CGFloat {
        switch self {
        case .soft: return 2
        case .medium: return 4
        }
    }
}

// MARK: - Shadow Extension
extension View {
    func dsShadow(_ style: DSShadow) -> some View {
        self.shadow(color: Color.black.opacity(style.opacity), radius: style.radius, y: style.y)
    }
}

// MARK: - Typography
enum DSTypography {
    case h1      // 48pt bold - text-5xl
    case h2      // 36pt bold - text-4xl
    case h3      // 30pt bold - text-3xl
    case h4      // 24pt semibold
    case h5      // 20pt semibold
    case body    // 16pt regular - text-base
    case bodyLarge // 18pt regular - text-lg
    case caption // 14pt regular
    case small   // 12pt regular

    var font: Font {
        switch self {
        case .h1: return .system(size: 48, weight: .bold, design: .default)
        case .h2: return .system(size: 36, weight: .bold, design: .default)
        case .h3: return .system(size: 30, weight: .bold, design: .default)
        case .h4: return .system(size: 24, weight: .semibold, design: .default)
        case .h5: return .system(size: 20, weight: .semibold, design: .default)
        case .body: return .system(size: 16, weight: .regular, design: .default)
        case .bodyLarge: return .system(size: 18, weight: .regular, design: .default)
        case .caption: return .system(size: 14, weight: .regular, design: .default)
        case .small: return .system(size: 12, weight: .regular, design: .default)
        }
    }
}

extension View {
    func dsFont(_ style: DSTypography) -> some View {
        self.font(style.font)
    }
}

// MARK: - Gradient Definitions
extension LinearGradient {
    static func dsPrimaryGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.dsPrimaryAdaptive(for: colorScheme),
                Color.dsPrimaryGlowAdaptive(for: colorScheme)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func dsSecondaryGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.dsSecondaryAdaptive(for: colorScheme),
                Color.dsAccentAdaptive(for: colorScheme)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
