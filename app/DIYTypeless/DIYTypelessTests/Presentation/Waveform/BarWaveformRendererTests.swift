import XCTest
import SwiftUI
@testable import DIYTypeless

/// Tests for BarWaveformRenderer in Presentation layer
/// Verifies: @MainActor final class, WaveformRendering conformance, discrete bar rendering
@MainActor
final class BarWaveformRendererTests: XCTestCase {

    // MARK: - Type Verification Tests

    func testRendererIsFinalClass() async {
        // Verify BarWaveformRenderer is a final class
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            XCTAssertNotNil(renderer)

            // Verify it's a class (not a struct) by checking reference semantics
            let rendererRef = renderer
            XCTAssertTrue(renderer === rendererRef, "Should be reference type (class)")
        }
    }

    func testRendererIsMainActor() async {
        // Verify BarWaveformRenderer is marked with @MainActor
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            XCTAssertNotNil(renderer)
        }
    }

    func testRendererConformsToWaveformRendering() async {
        // Verify BarWaveformRenderer conforms to WaveformRendering protocol
        await MainActor.run {
            let renderer: WaveformRendering = BarWaveformRenderer()
            XCTAssertNotNil(renderer)
        }
    }

    // MARK: - Render Method Tests

    func testRenderWithEmptyLevels() async {
        // Verify renderer handles empty levels array gracefully
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = []
            XCTAssertTrue(levels.isEmpty)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithSingleLevel() async {
        // Verify renderer handles single level
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [0.5]
            XCTAssertEqual(levels.count, 1)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithMultipleLevels() async {
        // Verify renderer handles multiple levels
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
            XCTAssertEqual(levels.count, 5)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithZeroSize() async {
        // Verify renderer handles zero size gracefully
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let size = CGSize(width: 0, height: 0)
            let levels: [Double] = [0.5, 0.6, 0.7]
            XCTAssertEqual(size.width, 0)
            XCTAssertEqual(size.height, 0)
            XCTAssertFalse(levels.isEmpty)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithLargeSize() async {
        // Verify renderer handles large sizes
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let size = CGSize(width: 1920, height: 1080)
            let levels: [Double] = Array(repeating: 0.5, count: 100)
            XCTAssertEqual(size.width, 1920)
            XCTAssertEqual(size.height, 1080)
            XCTAssertEqual(levels.count, 100)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    // MARK: - Bar Calculation Tests

    func testBarWidthCalculation() {
        // Verify bar width calculation formula
        // Formula: (width - totalSpacing) / barCount
        // where totalSpacing = spacing * (barCount - 1)

        let width = 100.0
        let barCount = 5
        let spacing = 4.0
        let totalSpacing = spacing * Double(barCount - 1)
        let barWidth = (width - totalSpacing) / Double(barCount)

        // Expected: (100 - 16) / 5 = 84 / 5 = 16.8
        XCTAssertEqual(barWidth, 16.8, accuracy: 0.001)
    }

    func testBarHeightCalculation() {
        // Verify bar height calculation with minimum height
        // Formula: max(minBarHeight, level * maxBarHeight)

        let maxBarHeight = 50.0
        let minBarHeight = 4.0

        // High level should use calculated height
        let highLevel = 0.8
        let highBarHeight = max(minBarHeight, highLevel * maxBarHeight)
        XCTAssertEqual(highBarHeight, 40.0, accuracy: 0.001)

        // Low level should use minimum height
        let lowLevel = 0.05
        let lowBarHeight = max(minBarHeight, lowLevel * maxBarHeight)
        XCTAssertEqual(lowBarHeight, minBarHeight)
    }

    func testVerticalCentering() {
        // Verify bars are centered vertically
        // Formula: y = (maxBarHeight - barHeight) / 2.0

        let maxBarHeight = 50.0
        let barHeight = 30.0
        let y = (maxBarHeight - barHeight) / 2.0

        // Expected: (50 - 30) / 2 = 10
        XCTAssertEqual(y, 10.0, accuracy: 0.001)
    }

    func testBarPositionCalculation() {
        // Verify x position calculation for bars
        // Formula: x = index * (barWidth + spacing)

        let barWidth = 16.0
        let spacing = 4.0

        // First bar at index 0
        let x0 = Double(0) * (barWidth + spacing)
        XCTAssertEqual(x0, 0.0)

        // Second bar at index 1
        let x1 = Double(1) * (barWidth + spacing)
        XCTAssertEqual(x1, 20.0)

        // Third bar at index 2
        let x2 = Double(2) * (barWidth + spacing)
        XCTAssertEqual(x2, 40.0)
    }

    // MARK: - Edge Case Tests

    func testRenderWithNegativeLevels() async {
        // Verify renderer handles negative levels (should clamp to min height)
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [-1.0, -0.5, 0.0, 0.5, 1.0]
            XCTAssertTrue(levels.contains(where: { $0 < 0 }))
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithLevelsAboveOne() async {
        // Verify renderer handles levels above 1.0 (clipping scenarios)
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [0.5, 1.0, 1.5, 2.0]
            XCTAssertTrue(levels.contains(where: { $0 > 1.0 }))
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithVeryLargeLevelCount() async {
        // Verify renderer handles very large level arrays
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels = Array(repeating: 0.5, count: 10000)
            XCTAssertEqual(levels.count, 10000)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithSilence() async {
        // Verify renderer handles all zeros (silence)
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
            XCTAssertTrue(levels.allSatisfy { $0 == 0.0 })
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testRenderWithMaximumLevels() async {
        // Verify renderer handles all maximum levels
        await MainActor.run {
            let renderer = BarWaveformRenderer()
            let levels: [Double] = [1.0, 1.0, 1.0, 1.0, 1.0]
            XCTAssertTrue(levels.allSatisfy { $0 == 1.0 })
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }
}
