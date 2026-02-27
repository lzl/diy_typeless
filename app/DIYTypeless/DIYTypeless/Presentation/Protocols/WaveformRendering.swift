import SwiftUI

/// Protocol for rendering waveform visualizations using SwiftUI GraphicsContext
/// Implementations must be @MainActor as GraphicsContext is a MainActor-bound type
@MainActor
protocol WaveformRendering: AnyObject {
    /// Renders the waveform visualization into the provided GraphicsContext
    /// - Parameters:
    ///   - context: The GraphicsContext to render into
    ///   - size: The size of the rendering area
    ///   - levels: Audio levels as normalized values (0.0...1.0)
    ///   - time: Current time for animation synchronization
    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    )
}
