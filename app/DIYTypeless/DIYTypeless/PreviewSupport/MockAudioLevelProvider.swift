#if DEBUG
import Combine
import SwiftUI

/// Mock implementation of AudioLevelProviding for previews and testing
@MainActor
@Observable
final class MockAudioLevelProvider: AudioLevelProviding, @unchecked Sendable {
    var levels: [Double] = Array(repeating: 0.1, count: 20)

    private var timer: Timer?
    private let pattern: WaveformPattern
    private var continuation: AsyncStream<[Double]>.Continuation?

    nonisolated var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            Task { @MainActor in
                self.continuation = continuation
            }
        }
    }

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
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.generateNextLevel()
            }
        }

        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        levels = Array(repeating: 0.1, count: 20)
    }

    // MARK: AudioLevelProviding protocol conformance

    func startMonitoring() throws {
        start()
    }

    func stopMonitoring() async {
        stop()
    }

    private func generateNextLevel() {
        let newLevel: Double
        let time = Date().timeIntervalSince1970

        switch pattern {
        case .sine:
            // Sine wave pattern
            newLevel = 0.5 + 0.4 * sin(time * 10)
        case .random:
            // Random pattern with smoothing
            newLevel = Double.random(in: 0.1 ... 1.0)
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

        // Emit to AsyncStream
        continuation?.yield(levels)
    }
}
#endif
