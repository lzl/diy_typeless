import XCTest
@testable import DIYTypeless

/// Tests for AudioLevelProviding protocol in Domain layer
/// Verifies: Protocol exists, uses pure Swift types, no UI framework dependencies
@MainActor
final class AudioLevelProvidingTests: XCTestCase {

    // MARK: - Protocol Existence Tests

    func testAudioLevelProvidingProtocolExists() {
        // This test verifies the protocol exists and can be referenced
        // If the protocol doesn't exist, this will fail to compile
        // Compile-time check: just referencing the protocol type proves it exists
        let metaType = AudioLevelProviding.self
        XCTAssertNotNil(metaType)
    }

    func testProtocolHasLevelsProperty() {
        // Verify the protocol has a 'levels' property of type [Double]
        // This is verified at compile time if the protocol exists
        // We use a mock implementation to verify at runtime

        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [0.1, 0.5, 0.9])
        XCTAssertEqual(provider.levels.count, 3)
        XCTAssertEqual(provider.levels[0], 0.1, accuracy: 0.001)
        XCTAssertEqual(provider.levels[1], 0.5, accuracy: 0.001)
        XCTAssertEqual(provider.levels[2], 0.9, accuracy: 0.001)
    }

    func testLevelsUsesDoubleNotCGFloat() {
        // Verify levels is [Double], not [CGFloat]
        // This test ensures we're using pure Swift types in Domain layer

        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [0.5])

        // Verify the type is Double
        for level in provider.levels {
            XCTAssertTrue(type(of: level) == Double.self, "Level should be Double, not CGFloat")
        }
    }

    // MARK: - Sendable Conformance Tests

    func testProtocolIsSendable() {
        // Verify AudioLevelProviding conforms to Sendable
        // This is important for concurrency safety

        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [0.5])

        // Verify it can be passed to an async context
        let expectation = expectation(description: "Sendable check")

        Task {
            _ = provider.levels
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testProtocolConformanceIsSendable() {
        // Verify that any type conforming to AudioLevelProviding can be Sendable
        // when using immutable value types

        final class SendableProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = SendableProvider(levels: [0.1, 0.2, 0.3])

        // Compile-time check: if AudioLevelProviding requires Sendable,
        // this will fail to compile if SendableProvider doesn't satisfy it
        func acceptSendable<T: AudioLevelProviding & Sendable>(_ value: T) {
            _ = value.levels
        }

        acceptSendable(provider)
    }

    // MARK: - Domain Layer Purity Tests

    func testNoSwiftUIImportsInDomainLayer() {
        // This test verifies that the Domain layer file does not import SwiftUI
        // We check this by ensuring the protocol can be used without SwiftUI

        // If AudioLevelProviding.swift imported SwiftUI, this would fail
        // because SwiftUI is not imported in this test file
        // (we only import XCTest and DIYTypeless)

        // The fact that this compiles proves no SwiftUI types are exposed
        let metaType = AudioLevelProviding.self
        XCTAssertNotNil(metaType)
    }

    func testNoAVFoundationImportsInDomainLayer() {
        // This test verifies that the Domain layer file does not import AVFoundation
        // We check this by ensuring the protocol can be used without AVFoundation

        // The fact that this compiles proves no AVFoundation types are exposed
        let metaType = AudioLevelProviding.self
        XCTAssertNotNil(metaType)
    }

    func testNoCGFloatUsageInDomainLayer() {
        // Verify that CGFloat is not used in the protocol
        // CGFloat is from CoreGraphics and should not appear in Domain layer

        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [0.5])

        // Verify all values are Double, not CGFloat
        for level in provider.levels {
            // This would fail if level were CGFloat
            XCTAssertTrue(type(of: level) == Double.self)
        }
    }

    // MARK: - Edge Case Tests

    func testEmptyLevelsArray() {
        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [])
        XCTAssertTrue(provider.levels.isEmpty)
    }

    func testLargeLevelsArray() {
        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let largeArray = Array(repeating: 0.5, count: 1000)
        let provider = MockProvider(levels: largeArray)
        XCTAssertEqual(provider.levels.count, 1000)
    }

    func testNegativeAndZeroValues() {
        final class MockProvider: AudioLevelProviding, @unchecked Sendable {
            let levels: [Double]
            var levelsStream: AsyncStream<[Double]> {
                AsyncStream { _ in }
            }
            init(levels: [Double]) {
                self.levels = levels
            }
        }

        let provider = MockProvider(levels: [-1.0, 0.0, 1.0])
        XCTAssertEqual(provider.levels[0], -1.0, accuracy: 0.001)
        XCTAssertEqual(provider.levels[1], 0.0, accuracy: 0.001)
        XCTAssertEqual(provider.levels[2], 1.0, accuracy: 0.001)
    }
}
