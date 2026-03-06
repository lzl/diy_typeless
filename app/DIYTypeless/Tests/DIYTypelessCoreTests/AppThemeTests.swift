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
}
#endif
