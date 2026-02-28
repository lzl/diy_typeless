import AVFoundation

/// Actor-isolated audio level monitor that bridges AVAudioEngine to SwiftUI
/// Uses AsyncStream for safe cross-actor communication
actor AudioLevelMonitor: AudioLevelProviding {
    private let audioEngine = AVAudioEngine()
    private var continuation: AsyncStream<[Double]>.Continuation?

    /// Current audio levels as normalized values (0.0...1.0)
    /// For real-time updates, prefer `levelsStream`
    nonisolated var levels: [Double] {
        []
    }

    /// AsyncStream that emits audio levels - safe for SwiftUI observation
    /// Creates a new stream each time - consumer must call this before startMonitoring
    nonisolated var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            // Store continuation for audio tap to use
            Task {
                await self.setContinuation(continuation)
            }
        }
    }

    private func setContinuation(_ cont: AsyncStream<[Double]>.Continuation) {
        self.continuation = cont
    }

    /// Start monitoring audio levels
    nonisolated func startMonitoring() throws {
        // Stop any existing monitoring first
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let levels = self.calculateLevels(from: buffer)
            Task {
                await self.yieldLevels(levels)
            }
        }

        try audioEngine.start()
    }

    private func yieldLevels(_ levels: [Double]) {
        continuation?.yield(levels)
    }

    /// Stop monitoring audio levels
    nonisolated func stopMonitoring() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        // Don't finish continuation - let the consumer control the stream lifecycle
    }

    /// Calculate normalized audio levels from PCM buffer
    /// Returns array of 20 Double values (0.0...1.0)
    nonisolated private func calculateLevels(from buffer: AVAudioPCMBuffer) -> [Double] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // Downsample to 20 bars
        let barCount = 20
        var levels: [Double] = []
        let samplesPerBar = frameLength / barCount

        for bar in 0..<barCount {
            let start = bar * samplesPerBar
            let end = min(start + samplesPerBar, frameLength)
            let slice = samples[start..<end]

            // Calculate RMS for this slice
            let sum = slice.map { Double($0 * $0) }.reduce(0, +)
            let rms = sqrt(sum / Double(slice.count))

            // Normalize with some headroom
            levels.append(min(rms * 4.0, 1.0))
        }

        return levels
    }
}
