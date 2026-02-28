import XCTest
import SwiftUI
@testable import DIYTypeless

/// Tests for WaveformRendererFactory in Presentation layer
/// Verifies: @MainActor, static factory method, correct renderer creation
@MainActor
final class WaveformRendererFactoryTests: XCTestCase {

    // MARK: - Factory Method Tests

    func testMakeRenderer_FluidStyle_ReturnsFluidRenderer() async {
        // Verify .fluid style returns FluidWaveformRenderer
        await MainActor.run {
            let renderer = WaveformRendererFactory.makeRenderer(for: .fluid)
            XCTAssertNotNil(renderer)
            XCTAssertTrue(renderer is FluidWaveformRenderer)
        }
    }

    func testMakeRenderer_BarsStyle_ReturnsBarRenderer() async {
        // Verify .bars style returns BarWaveformRenderer
        await MainActor.run {
            let renderer = WaveformRendererFactory.makeRenderer(for: .bars)
            XCTAssertNotNil(renderer)
            XCTAssertTrue(renderer is BarWaveformRenderer)
        }
    }

    func testMakeRenderer_DisabledStyle_ReturnsNil() async {
        // Verify .disabled style returns nil
        await MainActor.run {
            let renderer = WaveformRendererFactory.makeRenderer(for: .disabled)
            XCTAssertNil(renderer)
        }
    }

    // MARK: - Protocol Conformance Tests

    func testFluidRendererConformsToWaveformRendering() async {
        // Verify FluidWaveformRenderer conforms to WaveformRendering
        await MainActor.run {
            let renderer = WaveformRendererFactory.makeRenderer(for: .fluid)
            XCTAssertNotNil(renderer)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    func testBarRendererConformsToWaveformRendering() async {
        // Verify BarWaveformRenderer conforms to WaveformRendering
        await MainActor.run {
            let renderer = WaveformRendererFactory.makeRenderer(for: .bars)
            XCTAssertNotNil(renderer)
            XCTAssertTrue(renderer is WaveformRendering)
        }
    }

    // MARK: - All Styles Tests

    func testAllStylesAreHandled() async {
        // Verify all WaveformStyle cases are handled by the factory
        await MainActor.run {
            for style in WaveformStyle.allCases {
                let renderer = WaveformRendererFactory.makeRenderer(for: style)

                switch style {
                case .fluid:
                    XCTAssertNotNil(renderer, ".fluid should return a renderer")
                    XCTAssertTrue(renderer is FluidWaveformRenderer, ".fluid should return FluidWaveformRenderer")
                case .bars:
                    XCTAssertNotNil(renderer, ".bars should return a renderer")
                    XCTAssertTrue(renderer is BarWaveformRenderer, ".bars should return BarWaveformRenderer")
                case .disabled:
                    XCTAssertNil(renderer, ".disabled should return nil")
                }
            }
        }
    }

    // MARK: - Renderer Instance Tests

    func testFactoryCreatesNewInstances() async {
        // Verify factory creates new instances on each call
        await MainActor.run {
            let renderer1 = WaveformRendererFactory.makeRenderer(for: .fluid)
            let renderer2 = WaveformRendererFactory.makeRenderer(for: .fluid)

            XCTAssertNotNil(renderer1)
            XCTAssertNotNil(renderer2)

            // Should be different instances (not singleton)
            XCTAssertFalse(renderer1 === renderer2, "Factory should create new instances")
        }
    }

    func testBarRendererCreatesNewInstances() async {
        // Verify factory creates new BarWaveformRenderer instances
        await MainActor.run {
            let renderer1 = WaveformRendererFactory.makeRenderer(for: .bars)
            let renderer2 = WaveformRendererFactory.makeRenderer(for: .bars)

            XCTAssertNotNil(renderer1)
            XCTAssertNotNil(renderer2)

            // Should be different instances
            XCTAssertFalse(renderer1 === renderer2, "Factory should create new instances")
        }
    }
}
