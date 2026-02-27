import XCTest
import SwiftUI
@testable import DIYTypeless

/// Tests for WaveformSettings in Presentation layer
/// Verifies: @Observable without didSet, computed properties, UserDefaults persistence
@MainActor
final class WaveformSettingsTests: XCTestCase {

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "waveformStyle")
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "waveformStyle")
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSettingsInitializes() {
        let settings = WaveformSettings()
        XCTAssertNotNil(settings)
    }

    // MARK: - Default Style Tests

    func testDefaultStyleIsFluid() {
        let settings = WaveformSettings()

        // When no value is saved, default should be .fluid
        XCTAssertEqual(settings.selectedStyle, .fluid)
    }

    // MARK: - Style Selection Tests

    func testCanSelectFluidStyle() {
        let settings = WaveformSettings()

        settings.selectedStyle = .fluid

        XCTAssertEqual(settings.selectedStyle, .fluid)
    }

    func testCanSelectBarsStyle() {
        let settings = WaveformSettings()

        settings.selectedStyle = .bars

        XCTAssertEqual(settings.selectedStyle, .bars)
    }

    func testCanSelectDisabledStyle() {
        let settings = WaveformSettings()

        settings.selectedStyle = .disabled

        XCTAssertEqual(settings.selectedStyle, .disabled)
    }

    func testStyleChangeUpdatesValue() {
        let settings = WaveformSettings()

        // Start with .fluid
        settings.selectedStyle = .fluid
        XCTAssertEqual(settings.selectedStyle, .fluid)

        // Change to .bars
        settings.selectedStyle = .bars
        XCTAssertEqual(settings.selectedStyle, .bars)

        // Change to .disabled
        settings.selectedStyle = .disabled
        XCTAssertEqual(settings.selectedStyle, .disabled)
    }

    // MARK: - UserDefaults Persistence Tests

    func testStylePersistsToUserDefaults() {
        let settings = WaveformSettings()

        settings.selectedStyle = .bars

        // Verify value was saved to UserDefaults
        let savedValue = UserDefaults.standard.string(forKey: "waveformStyle")
        XCTAssertEqual(savedValue, "bars")
    }

    func testStyleLoadsFromUserDefaults() {
        // Set value in UserDefaults directly
        UserDefaults.standard.set("disabled", forKey: "waveformStyle")

        let settings = WaveformSettings()

        // Verify settings loaded the saved value
        XCTAssertEqual(settings.selectedStyle, .disabled)
    }

    func testInvalidUserDefaultsValueReturnsDefault() {
        // Set invalid value in UserDefaults
        UserDefaults.standard.set("invalid_style", forKey: "waveformStyle")

        let settings = WaveformSettings()

        // Should return default (.fluid) for invalid values
        XCTAssertEqual(settings.selectedStyle, .fluid)
    }

    func testNilUserDefaultsValueReturnsDefault() {
        // Ensure no value is set
        UserDefaults.standard.removeObject(forKey: "waveformStyle")

        let settings = WaveformSettings()

        // Should return default (.fluid) when no value is saved
        XCTAssertEqual(settings.selectedStyle, .fluid)
    }

    // MARK: - Cache Tests

    func testClearCacheWorks() {
        let settings = WaveformSettings()

        // Set a style
        settings.selectedStyle = .bars
        XCTAssertEqual(settings.selectedStyle, .bars)

        // Clear cache
        settings.clearCache()

        // Should still return correct value after clearing cache
        // (it will re-read from UserDefaults)
        XCTAssertEqual(settings.selectedStyle, .bars)
    }

    // MARK: - All Styles Test

    func testAllStylesCanBeSelected() {
        let settings = WaveformSettings()

        for style in WaveformStyle.allCases {
            settings.selectedStyle = style
            XCTAssertEqual(settings.selectedStyle, style)
        }
    }
}
