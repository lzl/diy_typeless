import XCTest
@testable import DIYTypeless

/// Tests for WaveformStyle enum in Domain layer
/// Verifies: Enum exists with correct cases, Sendable, String-backed, CaseIterable
@MainActor
final class WaveformStyleTests: XCTestCase {

    // MARK: - Enum Existence and Cases Tests

    func testWaveformStyleEnumExists() {
        // This test verifies the enum exists and can be referenced
        // If the enum doesn't exist, this will fail to compile
        let _: WaveformStyle.Type = WaveformStyle.self
    }

    func testEnumHasFluidCase() {
        // Verify .fluid case exists
        let style: WaveformStyle = .fluid
        XCTAssertEqual(style, .fluid)
    }

    func testEnumHasBarsCase() {
        // Verify .bars case exists
        let style: WaveformStyle = .bars
        XCTAssertEqual(style, .bars)
    }

    func testEnumHasDisabledCase() {
        // Verify .disabled case exists
        let style: WaveformStyle = .disabled
        XCTAssertEqual(style, .disabled)
    }

    func testAllCasesExist() {
        // Verify all expected cases exist
        let allCases = WaveformStyle.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.fluid))
        XCTAssertTrue(allCases.contains(.bars))
        XCTAssertTrue(allCases.contains(.disabled))
    }

    // MARK: - Sendable Conformance Tests

    func testEnumIsSendable() {
        // Verify WaveformStyle conforms to Sendable
        // This is important for concurrency safety

        func acceptSendable<T: Sendable>(_ value: T) {
            _ = value
        }

        // Compile-time check: if WaveformStyle is not Sendable, this will fail
        acceptSendable(WaveformStyle.fluid)
        acceptSendable(WaveformStyle.bars)
        acceptSendable(WaveformStyle.disabled)
    }

    func testEnumCanBeUsedInAsyncContext() {
        // Verify the enum can be safely passed between actors
        let expectation = expectation(description: "Async context check")

        Task {
            let style: WaveformStyle = .fluid
            _ = style
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - RawRepresentable (String-backed) Tests

    func testEnumIsStringBacked() {
        // Verify WaveformStyle uses String as RawValue
        // This is required for UserDefaults compatibility

        let style: WaveformStyle = .fluid
        XCTAssertEqual(style.rawValue, "fluid")

        let barsStyle: WaveformStyle = .bars
        XCTAssertEqual(barsStyle.rawValue, "bars")

        let disabledStyle: WaveformStyle = .disabled
        XCTAssertEqual(disabledStyle.rawValue, "disabled")
    }

    func testEnumCanBeInitializedFromRawValue() {
        // Verify we can create WaveformStyle from String raw value
        let fluid = WaveformStyle(rawValue: "fluid")
        XCTAssertEqual(fluid, .fluid)

        let bars = WaveformStyle(rawValue: "bars")
        XCTAssertEqual(bars, .bars)

        let disabled = WaveformStyle(rawValue: "disabled")
        XCTAssertEqual(disabled, .disabled)
    }

    func testEnumReturnsNilForInvalidRawValue() {
        // Verify invalid raw values return nil
        let invalid = WaveformStyle(rawValue: "invalid")
        XCTAssertNil(invalid)

        let empty = WaveformStyle(rawValue: "")
        XCTAssertNil(empty)
    }

    func testEnumRawValuesAreLowercase() {
        // Verify raw values are lowercase strings
        // This is a convention for UserDefaults keys
        XCTAssertEqual(WaveformStyle.fluid.rawValue, "fluid")
        XCTAssertEqual(WaveformStyle.bars.rawValue, "bars")
        XCTAssertEqual(WaveformStyle.disabled.rawValue, "disabled")
    }

    // MARK: - CaseIterable Tests

    func testEnumIsCaseIterable() {
        // Verify WaveformStyle conforms to CaseIterable
        // This allows iterating over all cases

        let allCases = WaveformStyle.allCases
        XCTAssertEqual(allCases.count, 3)
    }

    func testAllCasesContainsExpectedValues() {
        // Verify allCases contains exactly the expected values in order
        let allCases = WaveformStyle.allCases

        // Note: Order depends on declaration order in enum
        XCTAssertEqual(allCases[0], .fluid)
        XCTAssertEqual(allCases[1], .bars)
        XCTAssertEqual(allCases[2], .disabled)
    }

    // MARK: - Default Value Tests

    func testDefaultCaseIsFluid() {
        // Verify the default case is .fluid
        // This is used when no specific style has been selected

        // We verify this by checking that .fluid is the first case
        // and that it represents the default visualization style
        let defaultStyle: WaveformStyle = .fluid
        XCTAssertEqual(defaultStyle, .fluid)

        // Also verify fluid is the first in allCases (convention for default)
        XCTAssertEqual(WaveformStyle.allCases.first, .fluid)
    }

    // MARK: - Equatable Tests

    func testEnumIsEquatable() {
        // Verify WaveformStyle conforms to Equatable
        XCTAssertEqual(WaveformStyle.fluid, WaveformStyle.fluid)
        XCTAssertEqual(WaveformStyle.bars, WaveformStyle.bars)
        XCTAssertEqual(WaveformStyle.disabled, WaveformStyle.disabled)

        XCTAssertNotEqual(WaveformStyle.fluid, WaveformStyle.bars)
        XCTAssertNotEqual(WaveformStyle.bars, WaveformStyle.disabled)
        XCTAssertNotEqual(WaveformStyle.fluid, WaveformStyle.disabled)
    }

    // MARK: - Hashable Tests

    func testEnumIsHashable() {
        // Verify WaveformStyle conforms to Hashable
        // This is required for use in SwiftUI Picker and similar controls

        var hasher = Hasher()
        WaveformStyle.fluid.hash(into: &hasher)
        let fluidHash = hasher.finalize()

        hasher = Hasher()
        WaveformStyle.fluid.hash(into: &hasher)
        let fluidHash2 = hasher.finalize()

        XCTAssertEqual(fluidHash, fluidHash2)
    }

    // MARK: - UserDefaults Compatibility Tests

    func testEnumCanBeStoredInUserDefaults() {
        // Verify the enum can be stored and retrieved from UserDefaults
        // via its rawValue

        let key = "test_waveform_style"
        let defaults = UserDefaults.standard

        // Store via rawValue
        defaults.set(WaveformStyle.fluid.rawValue, forKey: key)

        // Retrieve via rawValue
        if let rawValue = defaults.string(forKey: key),
           let retrievedStyle = WaveformStyle(rawValue: rawValue) {
            XCTAssertEqual(retrievedStyle, .fluid)
        } else {
            XCTFail("Failed to retrieve style from UserDefaults")
        }

        // Clean up
        defaults.removeObject(forKey: key)
    }

    func testAllCasesCanBeStoredInUserDefaults() {
        let key = "test_waveform_style_all"
        let defaults = UserDefaults.standard

        for style in WaveformStyle.allCases {
            defaults.set(style.rawValue, forKey: key)

            if let rawValue = defaults.string(forKey: key),
               let retrievedStyle = WaveformStyle(rawValue: rawValue) {
                XCTAssertEqual(retrievedStyle, style)
            } else {
                XCTFail("Failed to store/retrieve style: \(style)")
            }
        }

        defaults.removeObject(forKey: key)
    }
}
