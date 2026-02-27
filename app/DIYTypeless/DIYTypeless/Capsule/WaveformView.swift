import SwiftUI

// MARK: - Waveform View
struct WaveformView: View {
    // MARK: Properties
    private let audioProvider: AudioLevelProviding

    // MARK: Initialization
    /// Creates a waveform view with an audio level provider
    /// - Parameter audioProvider: Provider conforming to AudioLevelProviding protocol
    init(audioProvider: AudioLevelProviding) {
        self.audioProvider = audioProvider
    }

    var body: some View {
        HStack(spacing: AppSize.waveformBarSpacing) {
            ForEach(audioProvider.levels.indices, id: \.self) { index in
                WaveformBar(level: audioProvider.levels[index])
            }
        }
    }
}

// MARK: - Waveform Bar Component
private struct WaveformBar: View {
    let level: Double

    /// Bar color - white with opacity based on level for subtle effect
    private var barColor: Color {
        .white.opacity(0.8 + (level * 0.2))
    }

    /// Calculate bar height based on level
    private var barHeight: CGFloat {
        max(AppSize.waveformBarWidth, AppSize.waveformMaxHeight * level)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: AppSize.waveformBarWidth / 2, style: .continuous)
            .fill(barColor)
            .frame(width: AppSize.waveformBarWidth, height: barHeight)
            .animation(.linear(duration: 0.05), value: level)
    }
}

