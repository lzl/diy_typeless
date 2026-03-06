#if !SWIFT_PACKAGE
import XCTest
@testable import DIYTypeless
import DIYTypelessCore

@MainActor
final class OnboardingCopyTests: XCTestCase {
    func testWelcomeChecklistUsesSetupPreviewCopyInOnboardingOrder() {
        XCTAssertEqual(OnboardingWelcomeContent.setupChecklistTitle, "What you'll set up")
        XCTAssertEqual(
            OnboardingWelcomeContent.setupChecklistItems,
            [
                .init(
                    systemName: "hand.raised.fill",
                    title: "Grant permissions",
                    detail: "Allow microphone and accessibility access."
                ),
                .init(
                    systemName: "key.fill",
                    title: "Add API keys",
                    detail: "Enter your Groq and Gemini keys."
                )
            ]
        )
    }

    func testCompletionPracticeLayoutUsesThreeLineField() {
        XCTAssertEqual(CompletionPracticeLayout.lineCount, 3)
    }

    func testCompletionPracticeGuidanceRetentionKeepsSuccessVisibleLonger() {
        XCTAssertEqual(CompletionPracticeGuidanceDisplayPolicy.successHoldDuration, 2.4)
    }

    func testPrimaryButtonHoverUsesDarkerFillToken() {
        XCTAssertEqual(PrimaryButtonPalette.hoverFillHex, "#5D7871")
        XCTAssertNotEqual(PrimaryButtonPalette.hoverFillHex, AppTheme.brandPrimaryLightHex)
    }

    func testCompletionPracticeGuidanceForHiddenState_promptsLiveTry() {
        XCTAssertEqual(
            CompletionPracticeGuidance.make(for: .hidden),
            .init(
                text: "Click in the box, hold Fn, speak, then release.",
                tone: .neutral
            )
        )
    }

    func testCompletionPracticeGuidanceForCopiedResult_teachesClipboardFallback() {
        XCTAssertEqual(
            CompletionPracticeGuidance.make(for: .done(.copied)),
            .init(
                text: "Copied to clipboard. Press Cmd+V in the box.",
                tone: .success
            )
        )
    }

    func testCompletionPracticeGuidanceForPastedResult_matchesEditorPosition() {
        XCTAssertEqual(
            CompletionPracticeGuidance.make(for: .done(.pasted)),
            .init(
                text: "Inserted above. Try another one or finish.",
                tone: .success
            )
        )
    }

    func testCompletionPracticeGuidanceForError_surfacesUserFacingMessage() {
        XCTAssertEqual(
            CompletionPracticeGuidance.make(for: .error(.networkError)),
            .init(
                text: "Network error, check connection",
                tone: .error
            )
        )
    }

    func testStepIconsUseSharedShadowFreeStyle() {
        XCTAssertEqual(OnboardingStepIconStyle.size, 88)
        XCTAssertEqual(OnboardingStepIconStyle.tintHex, AppTheme.brandPrimaryHex)
        XCTAssertEqual(OnboardingStepIconStyle.shadowOpacity, 0)
    }

    func testCapsuleFocusPolicyWhenAnotherWindowIsAlreadyKey_keepsCapsuleNonKey() {
        XCTAssertFalse(
            CapsuleFocusCapturePolicy.shouldCaptureKeyFocus(
                capsuleState: .recording,
                isResultLayerVisible: false,
                hasOtherKeyWindow: true
            )
        )
    }

    func testCapsuleFocusPolicyWhenNoOtherWindowIsKey_keepsExistingRecordingBehavior() {
        XCTAssertTrue(
            CapsuleFocusCapturePolicy.shouldCaptureKeyFocus(
                capsuleState: .recording,
                isResultLayerVisible: false,
                hasOtherKeyWindow: false
            )
        )
    }
}
#endif
