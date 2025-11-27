import SwiftUI

// MARK: - Design System
// Custom design system with light/dark mode support

// MARK: - Color Definitions (Dark mode adaptive)
extension Color {
    // Helper to get current color scheme
    private static var isDarkMode: Bool {
        if #available(macOS 14.0, *) {
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        } else {
            return NSApp.effectiveAppearance.name == .darkAqua
        }
    }

    // Background colors
    static var dsBackground: Color {
        isDarkMode ? Color(hex: "0F0F1A") : Color(hex: "FFFFFF")
    }

    static var dsForeground: Color {
        isDarkMode ? Color(hex: "F8FAFC") : Color(hex: "1A1A2E")
    }

    // Primary colors
    static var dsPrimary: Color {
        isDarkMode ? Color(hex: "818CF8") : Color(hex: "6366F1")
    }

    static var dsPrimaryGlow: Color {
        isDarkMode ? Color(hex: "A5B4FC") : Color(hex: "818CF8")
    }

    // Secondary and accent
    static var dsSecondary: Color {
        Color(hex: "22D3EE")
    }

    static var dsAccent: Color {
        isDarkMode ? Color(hex: "C4B5FD") : Color(hex: "A78BFA")
    }

    // Muted colors
    static var dsMuted: Color {
        isDarkMode ? Color(hex: "1E1E2E") : Color(hex: "F1F5F9")
    }

    static var dsMutedForeground: Color {
        isDarkMode ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }

    // Border and card
    static var dsBorder: Color {
        isDarkMode ? Color(hex: "2E2E3E") : Color(hex: "E2E8F0")
    }

    static var dsCard: Color {
        isDarkMode ? Color(hex: "1A1A2E") : Color(hex: "FFFFFF")
    }
}

// MARK: - Semantic Colors (Adaptive)
extension Color {
    // Adaptive colors that resolve at runtime based on color scheme
    static func dsBackgroundAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0F0F1A") : Color(hex: "FFFFFF")
    }

    static func dsForegroundAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "F8FAFC") : Color(hex: "1A1A2E")
    }

    static func dsPrimaryAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "818CF8") : Color(hex: "6366F1")
    }

    static func dsPrimaryGlowAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "A5B4FC") : Color(hex: "818CF8")
    }

    static func dsSecondaryAdaptive(for colorScheme: ColorScheme) -> Color {
        Color(hex: "22D3EE") // Same in both modes
    }

    static func dsAccentAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "C4B5FD") : Color(hex: "A78BFA")
    }

    static func dsMutedAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1E1E2E") : Color(hex: "F1F5F9")
    }

    static func dsMutedForegroundAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }

    static func dsBorderAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2E2E3E") : Color(hex: "E2E8F0")
    }

    static func dsCardAdaptive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1A1A2E") : Color(hex: "FFFFFF")
    }
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

// Primary button style
struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.dsPrimaryAdaptive(for: colorScheme),
                                Color.dsPrimaryGlowAdaptive(for: colorScheme)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Secondary button style
struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.dsPrimaryAdaptive(for: colorScheme))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .stroke(Color.dsBorderAdaptive(for: colorScheme), lineWidth: 1)
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
