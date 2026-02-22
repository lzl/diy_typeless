import AVFoundation
import Combine
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
    
    /// Map audio level to color (low = brandPrimary, high = brandAccent)
    private var barColor: Color {
        // Normalize level to 0.0-1.0 range for interpolation
        let normalizedLevel = min(1.0, max(0.0, level))
        
        // Interpolate between brandPrimary (low) and brandAccent (high)
        if normalizedLevel < 0.5 {
            // Low to medium: brandPrimary with increasing opacity
            return .brandPrimary.opacity(0.6 + (normalizedLevel * 0.4))
        } else {
            // Medium to high: blend toward brandAccent
            return .brandAccent.opacity(0.7 + ((normalizedLevel - 0.5) * 0.6))
        }
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

// MARK: - Mock Audio Level Provider
#if DEBUG
/// Mock implementation of AudioLevelProviding for previews and testing
@MainActor
@Observable
final class MockAudioLevelProvider: AudioLevelProviding {
    var levels: [CGFloat] = Array(repeating: 0.1, count: 20)
    
    private var timer: Timer?
    private let pattern: WaveformPattern
    
    enum WaveformPattern: Sendable {
        case sine
        case random
        case pulse
        case steady
    }
    
    init(pattern: WaveformPattern = .sine) {
        self.pattern = pattern
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.generateNextLevel()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        levels = Array(repeating: 0.1, count: 20)
    }
    
    private func generateNextLevel() {
        let newLevel: CGFloat
        let time = Date().timeIntervalSince1970
        
        switch pattern {
        case .sine:
            // Sine wave pattern
            newLevel = 0.5 + 0.4 * sin(time * 10)
        case .random:
            // Random pattern with smoothing
            newLevel = CGFloat.random(in: 0.1...1.0)
        case .pulse:
            // Periodic pulse
            let pulse = sin(time * 5)
            newLevel = pulse > 0.8 ? 1.0 : 0.2
        case .steady:
            // Steady low level
            newLevel = 0.3
        }
        
        var newLevels = levels
        newLevels.removeFirst()
        newLevels.append(max(0.1, newLevel))
        levels = newLevels
    }
}
#endif
