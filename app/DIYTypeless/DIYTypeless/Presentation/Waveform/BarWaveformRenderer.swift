import SwiftUI

/// Renders a discrete bar-style waveform visualization
/// Provides a classic audio meter aesthetic with rounded rectangular bars
@MainActor
final class BarWaveformRenderer: WaveformRendering {

    // MARK: - Configuration

    /// Spacing between bars in points
    private let spacing: Double = 4.0

    /// Minimum bar height in points (ensures visibility during silence)
    private let minBarHeight: Double = 4.0

    /// Corner radius for rounded bar corners
    private let cornerRadius: Double = 2.0

    // MARK: - WaveformRendering

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        let barCount = levels.count
        let totalSpacing = spacing * Double(barCount - 1)
        let barWidth = (Double(size.width) - totalSpacing) / Double(barCount)
        let maxBarHeight = Double(size.height)

        for (index, level) in levels.enumerated() {
            let x = Double(index) * (barWidth + spacing)
            let barHeight = max(minBarHeight, level * maxBarHeight)
            let y = (maxBarHeight - barHeight) / 2.0

            let rect = CGRect(
                x: x,
                y: y,
                width: barWidth,
                height: barHeight
            )
            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

            context.fill(path, with: .color(.accentColor))
        }
    }
}
