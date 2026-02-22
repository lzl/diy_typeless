import SwiftUI

// MARK: - Spacing System
// Consistent spacing values throughout the app

extension CGFloat {
    /// Extra small spacing (4pt)
    static let xs: CGFloat = 4

    /// Small spacing (8pt)
    static let sm: CGFloat = 8

    /// Medium spacing (16pt) - Standard spacing
    static let md: CGFloat = 16

    /// Large spacing (24pt)
    static let lg: CGFloat = 24

    /// Extra large spacing (32pt)
    static let xl: CGFloat = 32

    /// 2x Extra large spacing (48pt)
    static let xxl: CGFloat = 48

    /// 3x Extra large spacing (64pt)
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius System
extension CGFloat {
    /// Small corner radius (6pt)
    static let cornerSmall: CGFloat = 6

    /// Medium corner radius (8pt) - Standard
    static let cornerMedium: CGFloat = 8

    /// Large corner radius (12pt)
    static let cornerLarge: CGFloat = 12

    /// Extra large corner radius (16pt)
    static let cornerXLarge: CGFloat = 16

    /// Full corner radius for pills/circles
    static let cornerFull: CGFloat = 9999
}

// MARK: - Size Constants
enum AppSize {
    /// Capsule window width
    static let capsuleWidth: CGFloat = 180

    /// Capsule window height
    static let capsuleHeight: CGFloat = 50

    /// Onboarding window width
    static let onboardingWidth: CGFloat = 520

    /// Onboarding window height
    static let onboardingHeight: CGFloat = 480

    /// Icon size small
    static let iconSmall: CGFloat = 16

    /// Icon size medium
    static let iconMedium: CGFloat = 24

    /// Icon size large
    static let iconLarge: CGFloat = 32

    /// Icon size extra large
    static let iconXLarge: CGFloat = 48

    /// Button height standard
    static let buttonHeight: CGFloat = 36

    /// Button height large
    static let buttonHeightLarge: CGFloat = 44

    /// Progress bar height
    static let progressBarHeight: CGFloat = 4

    /// Waveform bar width
    static let waveformBarWidth: CGFloat = 3

    /// Waveform bar spacing
    static let waveformBarSpacing: CGFloat = 2

    /// Maximum waveform bar height
    static let waveformMaxHeight: CGFloat = 24
}
