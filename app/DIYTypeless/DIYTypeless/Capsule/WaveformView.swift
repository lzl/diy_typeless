import AVFoundation
import Combine
import os.log
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
    let level: CGFloat
    
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

// MARK: - Audio Level Monitor
@MainActor
@Observable
final class AudioLevelMonitor: AudioLevelProviding {
    // MARK: AudioLevelProviding Protocol
    var levels: [CGFloat] = Array(repeating: 0.1, count: 20)

    // MARK: Private Properties
    private var audioEngine: AVAudioEngine?
    private var isMonitoring = false
    private let logger = Logger(subsystem: "com.diytypeless.app", category: "AudioLevelMonitor")
    
    // MARK: Initialization
    nonisolated init() {}
    
    // MARK: AudioLevelProviding Methods
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let level = self.calculateLevel(buffer: buffer)
            Task { @MainActor in
                self.updateLevels(with: level)
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            isMonitoring = false
        }
    }
    
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        levels = Array(repeating: 0.1, count: 20)
    }
    
    // MARK: Private Methods
    nonisolated private func calculateLevel(buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let average = sum / Float(frameLength)
        let normalized = min(1.0, CGFloat(average) * 8)
        return normalized
    }
    
    private func updateLevels(with newLevel: CGFloat) {
        var newLevels = levels
        newLevels.removeFirst()
        newLevels.append(max(0.1, newLevel))
        levels = newLevels
    }
}

