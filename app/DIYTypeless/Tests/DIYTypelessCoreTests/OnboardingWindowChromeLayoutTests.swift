import AppKit
import XCTest
#if !SWIFT_PACKAGE
@testable import DIYTypeless

final class OnboardingWindowChromeLayoutTests: XCTestCase {
    func testTrafficLightOrigins_useShellInsetsAndStableSpacing() {
        let buttonSizes: [NSWindow.ButtonType: CGSize] = [
            .closeButton: CGSize(width: 14, height: 14),
            .miniaturizeButton: CGSize(width: 14, height: 14),
            .zoomButton: CGSize(width: 14, height: 14)
        ]
        let titlebarHeight: CGFloat = 32

        let origins = OnboardingWindowChromeLayout.trafficLightOrigins(
            for: buttonSizes,
            in: titlebarHeight
        )

        XCTAssertEqual(
            origins[.closeButton],
            CGPoint(
                x: OnboardingTheme.windowTrafficLightsLeadingInset,
                y: titlebarHeight - OnboardingTheme.windowTrafficLightsTopInset - 14
            )
        )
        XCTAssertEqual(
            origins[.miniaturizeButton],
            CGPoint(
                x: OnboardingTheme.windowTrafficLightsLeadingInset + 14 + OnboardingTheme.windowTrafficLightsSpacing,
                y: titlebarHeight - OnboardingTheme.windowTrafficLightsTopInset - 14
            )
        )
        XCTAssertEqual(
            origins[.zoomButton],
            CGPoint(
                x: OnboardingTheme.windowTrafficLightsLeadingInset + (14 + OnboardingTheme.windowTrafficLightsSpacing) * 2,
                y: titlebarHeight - OnboardingTheme.windowTrafficLightsTopInset - 14
            )
        )
    }

    func testWindowContentTopPadding_reservesChromeHeight() {
        XCTAssertGreaterThanOrEqual(
            OnboardingTheme.windowContentTopPadding,
            OnboardingTheme.windowChromeReservedHeight
        )
    }
}
#endif
