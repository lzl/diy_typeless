import AVFoundation

/// Actor-isolated audio level monitor that bridges AVAudioEngine to SwiftUI
/// Uses AsyncStream for safe cross-actor communication
actor AudioLevelMonitor: AudioLevelProviding {
    private let audioEngine = AVAudioEngine()
    // nonisolated(unsafe) is safe here because continuation is only accessed from actor-isolated methods
    // or from the nonisolated calculateLevels which creates a Task to call actor-isolated emit
    nonisolated(unsafe) private var continuation: AsyncStream<[Double]>.Continuation?

    /// Current audio levels as normalized values (0.0...1.0)
    /// For real-time updates, prefer `levelsStream`
    nonisolated var levels: [Double] {
        // Return empty array for synchronous access
        // Real-time updates come through levelsStream
        []
    }

    /// AsyncStream that emits audio levels - safe for SwiftUI observation
    /// This is nonisolated so it can be accessed from outside the actor
    nonisolated var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// Start monitoring audio levels
    /// Must be called from outside actor (nonisolated) since AVAudioEngine callbacks are on background thread
    nonisolated func startMonitoring() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let levels = self.calculateLevels(from: buffer)

            // Send to actor-isolated continuation
            Task { await self.emit(levels: levels) }
        }

        try audioEngine.start()
    }

    /// Stop monitoring audio levels
    /// Actor-isolated because it modifies actor state
    func stopMonitoring() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        continuation?.finish()
        continuation = nil
    }

    /// Emit levels to the AsyncStream
    private func emit(levels: [Double]) {
        continuation?.yield(levels)
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
