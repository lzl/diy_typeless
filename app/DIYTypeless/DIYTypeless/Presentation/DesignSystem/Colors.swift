import SwiftUI
import DIYTypelessCore

// MARK: - App Color System
// Pure presentation layer - no business logic

extension Color {
    // MARK: Background Colors
    static var appBackground: Color {
        dynamicColor(light: "#F3F5F4", dark: "#121715")
    }
    static var appBackgroundSecondary: Color {
        dynamicColor(light: "#EDF1F0", dark: "#171D1B")
    }
    static var appSurface: Color {
        dynamicColor(light: "#FCFDFC", dark: "#1C2220")
    }
    static var appSurfaceRaised: Color {
        dynamicColor(light: AppTheme.raisedSurfaceHex, dark: "#242B29")
    }
    static var appSurfaceSubtle: Color {
        dynamicColor(light: AppTheme.surfaceTintHex, dark: "#1A201E")
    }
    static var appBorderSubtle: Color {
        dynamicColor(light: AppTheme.borderHex, dark: "#313A37")
    }
    static var linkQuiet: Color {
        dynamicColor(light: AppTheme.quietLinkHex, dark: "#A5B2BD")
    }

    // MARK: Brand Colors
    static let brandPrimary = Color(hex: AppTheme.brandPrimaryHex)
    static let brandPrimaryDark = Color(hex: AppTheme.brandPrimaryDarkHex)
    static let brandPrimaryLight = Color(hex: AppTheme.brandPrimaryLightHex)
    static let brandAccent = Color(hex: AppTheme.brandAccentHex)
    static let brandAccentLight = Color(hex: AppTheme.brandAccentLightHex)

    // MARK: Semantic Colors
    static let success = Color(hex: AppTheme.successHex)
    static let warning = Color(hex: AppTheme.warningHex)
    static let error = Color(hex: AppTheme.errorHex)
    static let info = Color(hex: AppTheme.infoHex)

    // MARK: Text Colors
    static var textPrimary: Color {
        Color(nsColor: .labelColor)
    }
    static var textSecondary: Color {
        Color(nsColor: .secondaryLabelColor)
    }
    static var textMuted: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: Dynamic Colors
    static var glassBackground: Color {
        appSurfaceRaised.opacity(0.9)
    }

    static var glassBorder: Color {
        appBorderSubtle.opacity(0.6)
    }

    static var glowPrimary: Color {
        brandPrimary.opacity(0.18)
    }

    static var glowAccent: Color {
        brandAccent.opacity(0.15)
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

    fileprivate static func dynamicColor(light: String, dark: String) -> Color {
        Color(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return NSColor(hex: isDark ? dark : light)
                }
            )
        )
    }
}

// MARK: - Semantic Color Extensions
extension Color {
    /// Background color for active recording state
    static var recordingBackground: Color {
        error.opacity(0.16)
    }

    /// Background color for transcribing state
    static var transcribingBackground: Color {
        brandPrimary.opacity(0.14)
    }

    /// Background color for polishing state
    static var polishingBackground: Color {
        brandAccent.opacity(0.14)
    }

    /// Background color for completed state
    static var completedBackground: Color {
        success.opacity(0.16)
    }
}

// MARK: - Button Colors
extension Color {
    /// Primary button label color
    static let buttonPrimaryForeground = Color.white

    /// Primary button label color when disabled
    static var buttonPrimaryForegroundDisabled: Color {
        textMuted
    }

    /// Primary button background
    static var buttonPrimaryBackground: Color {
        brandPrimary
    }

    /// Primary button background when hovered
    static var buttonPrimaryBackgroundHover: Color {
        brandPrimaryDark
    }

    /// Primary button background when pressed
    static var buttonPrimaryBackgroundPressed: Color {
        brandPrimary.opacity(0.82)
    }

    /// Primary button background when disabled
    static var buttonPrimaryBackgroundDisabled: Color {
        brandPrimary.opacity(0.35)
    }

    /// Primary button border
    static var buttonPrimaryBorder: Color {
        brandPrimary.opacity(0.28)
    }

    /// Primary button border when hovered
    static var buttonPrimaryBorderHover: Color {
        buttonPrimaryBackgroundHover.opacity(0.42)
    }

    /// Primary button border when pressed
    static var buttonPrimaryBorderPressed: Color {
        brandPrimaryLight.opacity(0.32)
    }

    /// Primary button border when disabled
    static var buttonPrimaryBorderDisabled: Color {
        brandPrimary.opacity(0.1)
    }

    /// Secondary button background (neutral, adaptive)
    static var buttonSecondaryBackground: Color {
        appSurfaceRaised
    }

    /// Secondary button background when hovered
    static var buttonSecondaryBackgroundHover: Color {
        appSurfaceSubtle
    }

    /// Secondary button background when pressed
    static var buttonSecondaryBackgroundPressed: Color {
        appSurfaceSubtle.opacity(0.9)
    }

    /// Secondary button border
    static var buttonSecondaryBorder: Color {
        appBorderSubtle
    }

    /// Secondary button border when hovered
    static var buttonSecondaryBorderHover: Color {
        brandAccent.opacity(0.28)
    }

    /// Secondary button border when pressed
    static var buttonSecondaryBorderPressed: Color {
        appBorderSubtle.opacity(0.7)
    }

    /// Icon button background when hovered
    static var buttonIconBackgroundHover: Color {
        appSurfaceSubtle
    }

    /// Icon button background when pressed
    static var buttonIconBackgroundPressed: Color {
        appSurfaceSubtle.opacity(0.82)
    }

    /// Menu bar button background when hovered
    static var buttonMenuBackgroundHover: Color {
        appSurfaceSubtle
    }

    /// Menu bar button background when pressed
    static var buttonMenuBackgroundPressed: Color {
        appSurfaceSubtle.opacity(0.82)
    }

    /// Ghost button background when hovered
    static var buttonGhostBackgroundHover: Color {
        appSurfaceSubtle
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
