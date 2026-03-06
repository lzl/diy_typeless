import Foundation
import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

final class PrimaryButtonDesignSystemTests: XCTestCase {
    func testButtonStyles_usesDesignSystemTokensInsteadOfOnboardingPalette() throws {
        let source = try loadSourceFile(
            at: "app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ButtonStyles.swift"
        )

        XCTAssertFalse(
            source.contains("PrimaryButtonPalette"),
            "Design system button styles should not depend on onboarding-owned palette types."
        )
    }

    func testOnboardingCopy_doesNotDefinePrimaryButtonPalette() throws {
        let source = try loadSourceFile(
            at: "app/DIYTypeless/DIYTypeless/Onboarding/OnboardingCopy.swift"
        )

        XCTAssertFalse(
            source.contains("enum PrimaryButtonPalette"),
            "Onboarding copy should not define shared primary button tokens."
        )
    }

    func testColors_definesPrimaryButtonHoverToken() throws {
        let source = try loadSourceFile(
            at: "app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/Colors.swift"
        )

        XCTAssertTrue(
            source.contains("buttonPrimaryBackgroundHover"),
            "Design system colors should expose a semantic hover token for primary buttons."
        )
    }

    private func loadSourceFile(at relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let repositoryRoot = testsDirectory
            .appendingPathComponent("../../../..")
            .standardizedFileURL
        let fileURL = repositoryRoot
            .appendingPathComponent(relativePath)
            .standardizedFileURL

        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
