import SwiftUI
import DIYTypelessCore

enum AppTheme {
    static let brandPrimaryHex = "#6F8F87"
    static let brandPrimaryLightHex = "#A9C1BA"
    static let brandAccentHex = "#7F8C99"
    static let brandAccentLightHex = "#CAD2D8"

    static let successHex = "#6C907F"
    static let warningHex = "#B39A6B"
    static let errorHex = "#B57B72"
    static let infoHex = "#7F8C99"

    static let quietLinkHex = "#6F8593"
    static let surfaceTintHex = "#EEF2F1"
    static let raisedSurfaceHex = "#F7FAF9"
    static let borderHex = "#D7DFDC"
}

enum OnboardingTheme {
    static func providerBadgeHex(for provider: ApiProvider) -> String {
        switch provider {
        case .groq, .gemini:
            return AppTheme.brandAccentHex
        }
    }
}
