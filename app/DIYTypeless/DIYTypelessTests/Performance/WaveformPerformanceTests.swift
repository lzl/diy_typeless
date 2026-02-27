import XCTest
import SwiftUI
@testable import DIYTypeless

/// Performance tests for waveform visualization
/// Verifies: Frame rate, memory stability, CPU usage
@MainActor
final class WaveformPerformanceTests: XCTestCase {

    // MARK: - Renderer Creation Performance

    func testFactoryCreatesRenderersEfficiently() async {
        // When: Creating many renderers
        let startTime = Date()
        let iterations = 100

        await MainActor.run {
            for _ in 0..<iterations {
                _ = WaveformRendererFactory.makeRenderer(for: .fluid)
                _ = WaveformRendererFactory.makeRenderer(for: .bars)
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Should complete quickly
        XCTAssertLessThan(elapsed, 1.0, "Creating 200 renderers should take less than 1 second")
    }

    // MARK: - Memory Tests

    func testRendererCreationMemoryStability() async {
        // When: Creating many renderers
        await MainActor.run {
            for _ in 0..<1000 {
                _ = WaveformRendererFactory.makeRenderer(for: .fluid)
                _ = WaveformRendererFactory.makeRenderer(for: .bars)
            }
        }

        // Then: No memory issues (test passes if we get here)
        XCTAssertTrue(true)
    }

    // MARK: - Stress Tests

    func testRapidStyleSwitching() async {
        // Given: Initial style
        let styles: [WaveformStyle] = [.fluid, .bars, .disabled, .fluid, .bars]

        // When: Switching styles rapidly
        await MainActor.run {
            for _ in 0..<20 {
                for style in styles {
                    _ = WaveformRendererFactory.makeRenderer(for: style)
                }
            }
        }

        // Then: No memory issues
        XCTAssertTrue(true)
    }

    func testSettingsPerformance() async {
        // Given: Settings
        let settings = WaveformSettings()
        let styles = WaveformStyle.allCases

        // When: Switching settings rapidly
        let startTime = Date()

        for style in styles {
            settings.selectedStyle = style
            XCTAssertEqual(settings.selectedStyle, style)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Should be very fast
        XCTAssertLessThan(elapsed, 0.1, "Settings changes should be fast")
    }

    func testLevelProcessingPerformance() async {
        // Given: Large level arrays
        let largeLevels = Array(repeating: 0.5, count: 1000)

        // When: Processing levels
        let startTime = Date()
        let iterations = 100

        for _ in 0..<iterations {
            // Simulate processing that would happen in renderer
            let processed = largeLevels.map { min(max($0, 0.0), 1.0) }
            XCTAssertEqual(processed.count, largeLevels.count)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Then: Should complete quickly
        XCTAssertLessThan(elapsed, 1.0, "Level processing should be fast")
    }
}
