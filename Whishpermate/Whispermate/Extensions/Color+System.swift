import SwiftUI

// Extension to bridge NSColor system colors to SwiftUI's Color
extension Color {
    static var systemFill: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .systemFill)
        } else {
            // Fallback for macOS 13.x: use quaternaryLabel which is similar to systemFill
            return Color(nsColor: .labelColor)
        }
    }
    
    static var secondarySystemFill: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .secondarySystemFill)
        } else {
            // Fallback for macOS 13.x: use quaternaryLabel which is similar to systemFill
            return Color(nsColor: .secondaryLabelColor)
        }
    }
    
    static var tertiarySystemFill: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .tertiarySystemFill)
        } else {
            // Fallback for macOS 13.x: use quaternaryLabel which is similar to systemFill
            return Color(nsColor: .tertiaryLabelColor)
        }
    }
    
    static var quaternarySystemFill: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .quaternarySystemFill)
        } else {
            // Fallback for macOS 13.x: use quaternaryLabel which is similar to systemFill
            return Color(nsColor: .quaternaryLabelColor)
        }
    }
}
