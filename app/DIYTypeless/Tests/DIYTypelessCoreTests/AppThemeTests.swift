import XCTest
#if !SWIFT_PACKAGE
@testable import DIYTypeless
import DIYTypelessCore

final class AppThemeTests: XCTestCase {
    func testQuietBrandPaletteUsesCoolNeutralSharedTokens() {
        XCTAssertEqual(AppTheme.brandPrimaryHex, "#6F8F87")
        XCTAssertEqual(AppTheme.brandPrimaryLightHex, "#A9C1BA")
        XCTAssertEqual(AppTheme.brandAccentHex, "#7F8C99")
        XCTAssertEqual(AppTheme.brandAccentLightHex, "#CAD2D8")
    }

    func testOnboardingUsesSharedAccentForAllProviderBadges() {
        XCTAssertEqual(
            OnboardingTheme.providerBadgeHex(for: .groq),
            AppTheme.brandAccentHex
        )
        XCTAssertEqual(
            OnboardingTheme.providerBadgeHex(for: .gemini),
            AppTheme.brandAccentHex
        )
    }

    func testOnboardingUsesStableWindowAndViewportSizing() {
        XCTAssertEqual(AppSize.onboardingWidth, 560)
        XCTAssertEqual(AppSize.onboardingHeight, 660)
        XCTAssertEqual(OnboardingTheme.windowShellCornerRadius, 28)
        XCTAssertEqual(OnboardingTheme.windowOuterPadding, 0)
        XCTAssertEqual(OnboardingTheme.windowTrafficLightsLeadingInset, 14)
        XCTAssertEqual(OnboardingTheme.windowTrafficLightsTopInset, 14)
        XCTAssertEqual(OnboardingTheme.windowTrafficLightsSpacing, 8)
        XCTAssertEqual(OnboardingTheme.stepViewportMinHeight, 408)
        XCTAssertEqual(OnboardingTheme.contentColumnMaxWidth, 440)
        XCTAssertEqual(OnboardingTheme.stepViewportCornerRadius, 18)
    }
}
#endif
