import AVFoundation

/// Actor-isolated audio level monitor that bridges AVAudioEngine to SwiftUI
/// Uses AsyncStream for safe cross-actor communication
actor AudioLevelMonitor: AudioLevelProviding {
    private var audioEngine: AVAudioEngine?
    private var continuation: AsyncStream<[Double]>.Continuation?
    private var currentLevels: [Double] = Array(repeating: 0.0, count: 20)

    /// Current audio levels as normalized values (0.0...1.0)
    /// For real-time updates, prefer `levelsStream`
    var levels: [Double] {
        currentLevels
    }

    /// AsyncStream that emits audio levels - safe for SwiftUI observation
    /// Creates a new stream each time - consumer must call this before startMonitoring
    var levelsStream: AsyncStream<[Double]> {
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
    func startMonitoring() async throws {
        let audioEngine = ensureAudioEngine()

        // Stop any existing monitoring first
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let levels = Self.calculateLevels(from: buffer)
            Task {
                await self.yieldLevels(levels)
            }
        }

        try audioEngine.start()
    }

    private func yieldLevels(_ levels: [Double]) {
        currentLevels = levels
        continuation?.yield(levels)
    }

    /// Stop monitoring audio levels
    func stopMonitoring() async {
        guard let audioEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        // Don't finish continuation - let the consumer control the stream lifecycle
    }

    private func ensureAudioEngine() -> AVAudioEngine {
        if let audioEngine {
            return audioEngine
        }
        let engine = AVAudioEngine()
        audioEngine = engine
        return engine
    }

    /// Calculate normalized audio levels from PCM buffer
    /// Returns array of 20 Double values (0.0...1.0)
    private static func calculateLevels(from buffer: AVAudioPCMBuffer) -> [Double] {
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
