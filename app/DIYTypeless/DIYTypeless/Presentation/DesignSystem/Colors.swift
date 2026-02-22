import SwiftUI

// MARK: - App Color System
// Pure presentation layer - no business logic

extension Color {
    // MARK: Background Colors
    static let appBackground = Color(hex: "#0A0A0F")
    static let appBackgroundSecondary = Color(hex: "#141419")
    static let appSurface = Color(hex: "#1C1C24")

    // MARK: Brand Colors
    static let brandPrimary = Color(hex: "#0D9488")
    static let brandPrimaryLight = Color(hex: "#14B8A6")
    static let brandAccent = Color(hex: "#F97316")
    static let brandAccentLight = Color(hex: "#FB923C")

    // MARK: Semantic Colors
    static let success = Color(hex: "#10B981")
    static let warning = Color(hex: "#F59E0B")
    static let error = Color(hex: "#EF4444")
    static let info = Color(hex: "#3B82F6")

    // MARK: Text Colors
    static let textPrimary = Color(hex: "#F8FAFC")
    static let textSecondary = Color(hex: "#94A3B8")
    static let textMuted = Color(hex: "#64748B")

    // MARK: Dynamic Colors
    static var glassBackground: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.85)
    }

    static var glassBorder: Color {
        Color.white.opacity(0.1)
    }

    static var glowPrimary: Color {
        brandPrimary.opacity(0.3)
    }

    static var glowAccent: Color {
        brandAccent.opacity(0.3)
    }

    // MARK: - Hex Initializer
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

// MARK: - Semantic Color Extensions
extension Color {
    /// Background color for active recording state
    static var recordingBackground: Color {
        Color(hex: "#7F1D1D").opacity(0.3) // Deep red with opacity
    }

    /// Background color for transcribing state
    static var transcribingBackground: Color {
        brandPrimary.opacity(0.2)
    }

    /// Background color for polishing state
    static var polishingBackground: Color {
        brandAccent.opacity(0.2)
    }

    /// Background color for completed state
    static var completedBackground: Color {
        success.opacity(0.2)
    }
}
