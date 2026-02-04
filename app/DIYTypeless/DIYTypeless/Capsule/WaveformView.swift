import AVFoundation
import Combine
import SwiftUI

struct WaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: max(3, 16 * levels[index]))
            }
        }
    }
}

@MainActor
final class AudioLevelMonitor: ObservableObject {
    @Published var levels: [CGFloat] = Array(repeating: 0.1, count: 20)

    private var audioEngine: AVAudioEngine?
    private var isMonitoring = false

    deinit {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
    }

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
            DispatchQueue.main.async {
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

    private func calculateLevel(buffer: AVAudioPCMBuffer) -> CGFloat {
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
