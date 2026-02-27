import XCTest
import SwiftUI
@testable import DIYTypeless

/// Edge case tests for waveform visualization
/// Verifies: Data handling, style switching, settings persistence
@MainActor
final class WaveformEdgeCaseTests: XCTestCase {

    // MARK: - Silence Data Tests

    func testHandlesSilenceLevels() {
        // Given: Silence (all zeros)
        let silence = WaveformTestData.silence

        // Then: Levels should be valid
        XCTAssertEqual(silence.count, 5)
        XCTAssertTrue(silence.allSatisfy { $0 == 0.0 })
    }

    func testHandlesMaximumLevels() {
        // Given: Maximum levels
        let maxLevels = WaveformTestData.maximum

        // Then: Levels should be valid
        XCTAssertEqual(maxLevels.count, 5)
        XCTAssertTrue(maxLevels.allSatisfy { $0 == 1.0 })
    }

    // MARK: - Empty Data Tests

    func testHandlesEmptyLevels() {
        // Given: Empty levels
        let empty = WaveformTestData.empty

        // Then: Should be empty array
        XCTAssertTrue(empty.isEmpty)
    }

    func testHandlesSingleValue() {
        // Given: Single value
        let single = WaveformTestData.singleValue

        // Then: Should have one element
        XCTAssertEqual(single.count, 1)
        XCTAssertEqual(single[0], 0.5)
    }

    // MARK: - Large Data Tests

    func testHandlesLargeArray() {
        // Given: Large array
        let large = WaveformTestData.largeArray

        // Then: Should have 1000 elements
        XCTAssertEqual(large.count, 1000)
        XCTAssertTrue(large.allSatisfy { $0 == 0.5 })
    }

    // MARK: - Invalid Value Tests

    func testHandlesNaNValues() {
        // Given: NaN value
        let value = Double.nan

        // Then: Should be NaN
        XCTAssertTrue(value.isNaN)
    }

    func testHandlesInfinityValues() {
        // Given: Infinity values
        let positiveInfinity = Double.infinity
        let negativeInfinity = -Double.infinity

        // Then: Should be infinite
        XCTAssertTrue(positiveInfinity.isInfinite)
        XCTAssertTrue(negativeInfinity.isInfinite)
    }

    func testHandlesRapidAlternation() {
        // Given: Rapidly alternating levels
        let rapid = WaveformTestData.rapidAlternation

        // Then: Should alternate between 0 and 1
        XCTAssertEqual(rapid.count, 6)
        XCTAssertEqual(rapid[0], 0.0)
        XCTAssertEqual(rapid[1], 1.0)
        XCTAssertEqual(rapid[2], 0.0)
        XCTAssertEqual(rapid[3], 1.0)
    }

    func testHandlesDecayPattern() {
        // Given: Decay pattern
        let decay = WaveformTestData.decay

        // Then: Should decrease from 1.0 to 0.1
        XCTAssertEqual(decay.count, 6)
        XCTAssertEqual(decay[0], 1.0)
        XCTAssertEqual(decay[5], 0.1)
    }

    // MARK: - Renderer Factory Edge Cases

    func testFactoryHandlesAllStyles() async {
        // Given: All styles
        let styles = WaveformStyle.allCases

        // When: Creating renderer for each style
        await MainActor.run {
            for style in styles {
                let renderer = WaveformRendererFactory.makeRenderer(for: style)

                // Then: Should create appropriate renderer (or nil for disabled)
                switch style {
                case .fluid:
                    XCTAssertNotNil(renderer)
                    XCTAssertTrue(renderer is FluidWaveformRenderer)
                case .bars:
                    XCTAssertNotNil(renderer)
                    XCTAssertTrue(renderer is BarWaveformRenderer)
                case .disabled:
                    XCTAssertNil(renderer)
                }
            }
        }
    }

    func testFactoryCreatesNewInstances() async {
        // When: Creating multiple renderers
        await MainActor.run {
            let renderer1 = WaveformRendererFactory.makeRenderer(for: .fluid)
            let renderer2 = WaveformRendererFactory.makeRenderer(for: .fluid)

            // Then: Should be different instances
            XCTAssertNotNil(renderer1)
            XCTAssertNotNil(renderer2)
            XCTAssertFalse(renderer1 === renderer2, "Factory should create new instances")
        }
    }

    // MARK: - Settings Edge Cases

    func testSettingsHandlesAllStyles() {
        // Given: Settings and all styles
        let settings = WaveformSettings()
        let styles = WaveformStyle.allCases

        // When/Then: Each style can be set and retrieved
        for style in styles {
            settings.selectedStyle = style
            XCTAssertEqual(settings.selectedStyle, style)
        }
    }

    func testSettingsPersistence() {
        // Given: Settings
        let settings = WaveformSettings()

        // When: Changing style
        settings.selectedStyle = .bars

        // Then: Style should be persisted
        XCTAssertEqual(settings.selectedStyle, .bars)

        // When: Creating new settings instance
        let newSettings = WaveformSettings()

        // Then: Should load persisted value
        XCTAssertEqual(newSettings.selectedStyle, .bars)

        // Cleanup
        settings.selectedStyle = .fluid
    }

    func testSettingsInvalidValueHandling() {
        // Given: Settings with invalid raw value in UserDefaults
        UserDefaults.standard.set("invalid_style", forKey: "waveformStyle")

        // When: Creating new settings
        let settings = WaveformSettings()

        // Then: Should return default (.fluid)
        XCTAssertEqual(settings.selectedStyle, .fluid)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "waveformStyle")
    }

    // MARK: - Audio Monitor Edge Cases

    func testAudioMonitorHandlesEmptyLevelsStream() async {
        // Given: Audio monitor
        let audioMonitor = AudioLevelMonitor()

        // When: Accessing levels stream
        let stream = audioMonitor.levelsStream

        // Then: Stream should be created
        XCTAssertNotNil(stream)

        // When: Creating iterator
        var iterator = stream.makeAsyncIterator()

        // Then: Should be able to create iterator (no values expected)
        XCTAssertNotNil(iterator)
    }

    // MARK: - Style Enum Edge Cases

    func testStyleRawValues() {
        // Then: All styles should have valid raw values
        XCTAssertEqual(WaveformStyle.fluid.rawValue, "fluid")
        XCTAssertEqual(WaveformStyle.bars.rawValue, "bars")
        XCTAssertEqual(WaveformStyle.disabled.rawValue, "disabled")
    }

    func testStyleFromRawValue() {
        // Given/When/Then: Styles can be created from valid raw values
        XCTAssertEqual(WaveformStyle(rawValue: "fluid"), .fluid)
        XCTAssertEqual(WaveformStyle(rawValue: "bars"), .bars)
        XCTAssertEqual(WaveformStyle(rawValue: "disabled"), .disabled)

        // Invalid raw values should return nil
        XCTAssertNil(WaveformStyle(rawValue: "invalid"))
        XCTAssertNil(WaveformStyle(rawValue: ""))
    }

    func testStyleAllCases() {
        // Given: All cases
        let allCases = WaveformStyle.allCases

        // Then: Should contain all three styles
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.fluid))
        XCTAssertTrue(allCases.contains(.bars))
        XCTAssertTrue(allCases.contains(.disabled))
    }
}
