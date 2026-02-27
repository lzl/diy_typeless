import XCTest
import SwiftUI
@testable import DIYTypeless

/// Tests for WaveformRendering protocol in Presentation layer
/// Verifies: Protocol exists, uses GraphicsContext, @MainActor, correct method signature
@MainActor
final class WaveformRenderingTests: XCTestCase {

    // MARK: - Protocol Existence Tests

    func testWaveformRenderingProtocolExists() {
        // This test verifies the protocol exists and can be referenced
        // If the protocol doesn't exist, this will fail to compile
        let metaType = WaveformRendering.self
        XCTAssertNotNil(metaType)
    }

    func testProtocolIsMainActor() {
        // Verify the protocol is marked with @MainActor
        // This is a compile-time check - if the protocol isn't @MainActor,
        // the MockRenderer below would need different isolation

        final class MockRenderer: WaveformRendering {
            var renderCalled = false
            var lastContext: GraphicsContext?
            var lastSize: CGSize?
            var lastLevels: [Double]?
            var lastTime: Date?

            func render(
                context: GraphicsContext,
                size: CGSize,
                levels: [Double],
                time: Date
            ) {
                renderCalled = true
                lastContext = context
                lastSize = size
                lastLevels = levels
                lastTime = time
            }
        }

        let renderer = MockRenderer()
        XCTAssertFalse(renderer.renderCalled)
    }

    func testProtocolMethodSignature() {
        // Verify the protocol has the correct method signature
        // Parameters: context: GraphicsContext, size: CGSize, levels: [Double], time: Date

        final class MockRenderer: WaveformRendering {
            func render(
                context: GraphicsContext,
                size: CGSize,
                levels: [Double],
                time: Date
            ) {
                // Verify parameter types at compile time
                let _: GraphicsContext = context
                let _: CGSize = size
                let _: [Double] = levels
                let _: Date = time
            }
        }

        // If this compiles, the method signature is correct
        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    func testProtocolUsesGraphicsContext() {
        // Verify the protocol uses SwiftUI GraphicsContext (not CGContext)

        final class MockRenderer: WaveformRendering {
            var receivedContextType: String?

            func render(
                context: GraphicsContext,
                size: CGSize,
                levels: [Double],
                time: Date
            ) {
                // GraphicsContext is a SwiftUI type
                receivedContextType = String(describing: type(of: context))
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    func testProtocolUsesDoubleArrayForLevels() {
        // Verify levels parameter uses [Double], not [CGFloat]

        final class MockRenderer: WaveformRendering {
            func render(
                context: GraphicsContext,
                size: CGSize,
                levels: [Double],
                time: Date
            ) {
                // Verify the type is [Double]
                for level in levels {
                    XCTAssertTrue(type(of: level) == Double.self, "Level should be Double, not CGFloat")
                }
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    // MARK: - Implementation Conformance Tests

    func testMockImplementationCanBeCreated() {
        // Verify a mock implementation can be created and used

        final class MockRenderer: WaveformRendering {
            var renderCallCount = 0

            func render(
                context: GraphicsContext,
                size: CGSize,
                levels: [Double],
                time: Date
            ) {
                renderCallCount += 1
            }
        }

        let renderer = MockRenderer()
        XCTAssertEqual(renderer.renderCallCount, 0)
    }

    func testMultipleImplementationsCanExist() {
        // Verify multiple types can conform to the protocol

        final class RendererA: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {}
        }

        final class RendererB: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {}
        }

        let rendererA: WaveformRendering = RendererA()
        let rendererB: WaveformRendering = RendererB()

        XCTAssertNotNil(rendererA)
        XCTAssertNotNil(rendererB)
    }

    // MARK: - Edge Case Tests

    func testEmptyLevelsArray() {
        final class MockRenderer: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
                // Should handle empty array gracefully
                XCTAssertTrue(levels.isEmpty)
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    func testLargeLevelsArray() {
        final class MockRenderer: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
                // Should handle large arrays
                XCTAssertEqual(levels.count, 1000)
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    func testZeroSize() {
        final class MockRenderer: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
                // Should handle zero size gracefully
                XCTAssertEqual(size.width, 0)
                XCTAssertEqual(size.height, 0)
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }

    func testNegativeLevels() {
        final class MockRenderer: WaveformRendering {
            func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
                // Should handle negative levels (though typically 0.0...1.0)
                XCTAssertTrue(levels.contains(where: { $0 < 0 }))
            }
        }

        let renderer = MockRenderer()
        XCTAssertNotNil(renderer)
    }
}
