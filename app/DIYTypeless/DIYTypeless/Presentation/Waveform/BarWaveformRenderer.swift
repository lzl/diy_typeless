import SwiftUI

/// Renders a discrete bar-style waveform visualization
/// Matches the original WaveformView implementation exactly
@MainActor
final class BarWaveformRenderer: WaveformRendering {

    // MARK: - State

    /// Smoothed levels for fluid animation
    private var smoothedLevels: [Double] = []

    // MARK: - Configuration (matches original WaveformView)

    /// Bar width - matches AppSize.waveformBarWidth
    private let barWidth: Double = 3.0

    /// Spacing between bars - matches AppSize.waveformBarSpacing
    private let spacing: Double = 2.0

    /// Maximum bar height - matches AppSize.waveformMaxHeight
    private let maxBarHeight: Double = 24.0

    /// Corner radius - matches original (barWidth / 2)
    private var cornerRadius: Double { barWidth / 2 }

    /// Animation smoothing factor tuned to match 0.05s linear animation
    private let smoothingAlpha: Double = 0.35

    // MARK: - WaveformRendering

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard size.width > 0, size.height > 0 else { return }

        // Apply smoothing for fluid animation
        updateSmoothedLevels(with: levels)
        let displayLevels = smoothedLevels.isEmpty ? levels : smoothedLevels
        guard !displayLevels.isEmpty else { return }

        // Calculate how many bars fit in the given width
        let totalBarSpace = barWidth + spacing
        let maxBars = Int((Double(size.width) + spacing) / totalBarSpace)
        let barCount = min(displayLevels.count, maxBars)

        // Calculate starting x to center the bars
        let totalWidth = Double(barCount) * barWidth + Double(barCount - 1) * spacing
        let startX = (Double(size.width) - totalWidth) / 2
        let centerY = Double(size.height) / 2

        for index in 0..<barCount {
            let level = displayLevels[index]
            let x = startX + Double(index) * totalBarSpace

            // Height calculation matches original: max(barWidth, maxHeight * level)
            let barHeight = max(barWidth, maxBarHeight * level)

            // Center vertically
            let y = centerY - (barHeight / 2)

            let rect = CGRect(
                x: x,
                y: y,
                width: barWidth,
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)

            // Color matches original: white.opacity(0.8 + level * 0.2)
            let opacity = 0.8 + (level * 0.2)
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }

    // MARK: - Private Methods

    /// Exponential smoothing for fluid animation matching SwiftUI's .linear(duration: 0.05)
    private func updateSmoothedLevels(with newLevels: [Double]) {
        if smoothedLevels.count != newLevels.count {
            smoothedLevels = newLevels
            return
        }

        for index in 0..<newLevels.count {
            let newValue = newLevels[index]
            let oldValue = smoothedLevels[index]
            smoothedLevels[index] = smoothingAlpha * newValue + (1.0 - smoothingAlpha) * oldValue
        }
    }
}
