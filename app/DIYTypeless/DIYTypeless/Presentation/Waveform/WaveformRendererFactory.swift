import SwiftUI

/// Factory for creating waveform renderer instances based on style
/// Returns appropriate renderer for each WaveformStyle enum case
@MainActor
enum WaveformRendererFactory {

    /// Creates a waveform renderer for the specified style
    /// - Parameter style: The waveform style to create a renderer for
    /// - Returns: A WaveformRendering instance, or nil for .disabled style
    static func makeRenderer(for style: WaveformStyle) -> WaveformRendering? {
        switch style {
        case .fluid:
            return FluidWaveformRenderer()
        case .bars:
            return BarWaveformRenderer()
        case .disabled:
            return nil
        }
    }
}
