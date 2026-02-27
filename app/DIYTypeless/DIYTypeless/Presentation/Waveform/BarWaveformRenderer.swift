import SwiftUI

/// Renders an elegant, smooth bar-style waveform visualization
/// Provides fluid animation with exponential smoothing for a premium feel
@MainActor
final class BarWaveformRenderer: WaveformRendering {

    // MARK: - State

    /// Smoothed levels for fluid animation between frames
    private var smoothedLevels: [Double] = []

    // MARK: - Configuration

    /// Spacing between bars
    private let spacing: Double = 2.0

    /// Minimum bar height for visibility during silence
    private let minBarHeight: Double = 2.0

    /// Corner radius for bar ends
    private let cornerRadius: Double = 1.0

    /// Exponential smoothing factor (0.0 = no movement, 1.0 = instant)
    /// Lower = smoother/slower, Higher = more responsive
    private let smoothingAlpha: Double = 0.25

    /// Bar color - subtle white
    private let barColor: Color = .white.opacity(0.85)

    // MARK: - WaveformRendering

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard size.width > 0, size.height > 0 else { return }

        // Update smoothed levels for fluid animation
        updateSmoothedLevels(with: levels)

        let displayLevels = smoothedLevels.isEmpty ? levels : smoothedLevels
        guard !displayLevels.isEmpty else { return }

        let barCount = displayLevels.count
        let totalSpacing = spacing * Double(barCount - 1)
        let availableWidth = Double(size.width) - totalSpacing
        let barWidth = availableWidth / Double(barCount)
        let maxBarHeight = Double(size.height)
        let centerY = maxBarHeight / 2.0

        for (index, level) in displayLevels.enumerated() {
            let x = Double(index) * (barWidth + spacing)

            // Calculate bar height with minimum for visibility
            let barHeight = max(minBarHeight, level * maxBarHeight)

            // Center vertically
            let y = centerY - (barHeight / 2.0)

            // Create rounded bar
            let rect = CGRect(
                x: x,
                y: y,
                width: max(0.5, barWidth),
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

            // Subtle opacity variation based on level
            let opacity = 0.6 + (level * 0.4)
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }

    // MARK: - Private Methods

    /// Updates smoothed levels using exponential smoothing for fluid animation
    private func updateSmoothedLevels(with newLevels: [Double]) {
        // Initialize if count changed
        if smoothedLevels.count != newLevels.count {
            smoothedLevels = newLevels
            return
        }

        // Apply exponential smoothing: smoothed = alpha * new + (1 - alpha) * old
        for index in 0..<newLevels.count {
            let newValue = newLevels[index]
            let oldValue = smoothedLevels[index]
            smoothedLevels[index] = smoothingAlpha * newValue + (1.0 - smoothingAlpha) * oldValue
        }
    }
}
