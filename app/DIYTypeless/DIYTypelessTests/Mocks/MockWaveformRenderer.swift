import SwiftUI
@testable import DIYTypeless

/// Mock renderer for testing waveform rendering
/// Tracks render calls and captures last render parameters
@MainActor
final class MockWaveformRenderer: WaveformRendering {
    var renderCallCount = 0
    var lastRenderParameters: (size: CGSize, levels: [Double], time: Date)?

    func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
        renderCallCount += 1
        lastRenderParameters = (size, levels, time)
    }
}
