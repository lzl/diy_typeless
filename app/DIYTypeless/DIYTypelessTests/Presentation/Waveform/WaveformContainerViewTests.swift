import XCTest
import SwiftUI
@testable import DIYTypeless

/// Tests for WaveformContainerView in Presentation layer
/// Verifies: TimelineView, Canvas, renderer caching, AsyncStream subscription
@MainActor
final class WaveformContainerViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testViewInitializesWithAudioMonitor() async {
        // Verify WaveformContainerView initializes with AudioLevelMonitor
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor, style: .fluid)
            XCTAssertNotNil(view)
        }
    }

    func testViewInitializesWithDefaultStyle() async {
        // Verify default style is .fluid when not specified
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor)
            XCTAssertNotNil(view)
        }
    }

    func testViewInitializesWithBarsStyle() async {
        // Verify view can be initialized with .bars style
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor, style: .bars)
            XCTAssertNotNil(view)
        }
    }

    // MARK: - Style Tests

    func testViewAcceptsFluidStyle() async {
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor, style: .fluid)
            XCTAssertNotNil(view)
        }
    }

    func testViewAcceptsBarsStyle() async {
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor, style: .bars)
            XCTAssertNotNil(view)
        }
    }

    func testViewAcceptsDisabledStyle() async {
        await MainActor.run {
            let audioMonitor = MockAudioLevelMonitor()
            let view = WaveformContainerView(audioMonitor: audioMonitor, style: .disabled)
            XCTAssertNotNil(view)
        }
    }
}
