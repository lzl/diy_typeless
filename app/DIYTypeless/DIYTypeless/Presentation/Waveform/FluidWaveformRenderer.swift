import SwiftUI

/// Renders a fluid, organic waveform using layered sine waves
/// Produces a smooth, wave-like visualization that responds to audio levels
@MainActor
final class FluidWaveformRenderer: WaveformRendering {

    // MARK: - State

    /// Smoothed audio levels maintained across frames for fluid animation
    private var smoothedLevels: [Double] = []

    /// Exponential smoothing factor (0.0...1.0)
    /// Lower values = smoother but more lag, higher values = more responsive but jittery
    private let smoothingAlpha: Double = 0.3

    // MARK: - WaveformRendering

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard size.width > 0, size.height > 0 else { return }

        // Update smoothed levels with exponential smoothing
        updateSmoothedLevels(with: levels)

        // Use smoothed levels if available, otherwise use raw levels
        let displayLevels = smoothedLevels.isEmpty ? levels : smoothedLevels

        guard !displayLevels.isEmpty else { return }

        // Calculate time-based animation offset
        let timeOffset = time.timeIntervalSinceReferenceDate

        // Build and stroke the waveform line (no fill)
        let width = size.width
        let height = size.height
        let centerY = height / 2

        // Number of points to render
        let pointCount = displayLevels.count
        let stepX = width / max(CGFloat(pointCount - 1), 1)

        // Build stroke path
        var strokePath = Path()

        for (index, level) in displayLevels.enumerated() {
            let x = CGFloat(index) * stepX

            // Calculate three-layer sine wave
            let normalizedX = Double(index) / Double(max(pointCount - 1, 1))

            // Layer 1: Primary wave (base frequency)
            let freq1 = 4.0 * Double.pi
            let phase1 = timeOffset * 2.0
            let amplitude1 = level * Double(centerY) * 0.8

            // Layer 2: Secondary wave (higher frequency, half amplitude)
            let freq2 = 8.0 * Double.pi
            let phase2 = timeOffset * 3.0
            let amplitude2 = level * Double(centerY) * 0.6

            // Layer 3: Tertiary wave (dynamic frequency, smaller contribution)
            let freq3 = 12.0 * Double.pi
            let amplitude3 = level * Double(centerY) * 0.4

            // Combine all three layers
            let yOffset = sin(normalizedX * freq1 + phase1) * amplitude1 +
                         sin(normalizedX * freq2 + phase2) * amplitude2 * 0.5 +
                         sin(normalizedX * freq3 + timeOffset * 0.5) * amplitude3 * 0.3

            let y = centerY + CGFloat(yOffset)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                strokePath.move(to: point)
            } else {
                strokePath.addLine(to: point)
            }
        }

        // Stroke with semantic color
        context.stroke(
            strokePath,
            with: .color(Color.primary),
            lineWidth: 2
        )
    }

    // MARK: - Private Methods

    /// Updates smoothed levels using exponential smoothing
    private func updateSmoothedLevels(with newLevels: [Double]) {
        // Initialize if needed
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
