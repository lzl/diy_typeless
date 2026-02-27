import Foundation
@testable import DIYTypeless

/// Mock audio level monitor for testing and previews
/// Simulates audio levels without requiring actual audio input
@MainActor
final class MockAudioLevelMonitor: AudioLevelProviding, @unchecked Sendable {
    private(set) var levels: [Double] = []
    private var continuation: AsyncStream<[Double]>.Continuation?
    private let lock = NSLock()

    var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()
        }
    }

    init(levels: [Double] = []) {
        self.levels = levels
    }

    /// Simulate audio level updates
    func simulateLevels(_ newLevels: [Double]) {
        lock.lock()
        levels = newLevels
        continuation?.yield(newLevels)
        lock.unlock()
    }

    /// Start a continuous simulation with animated levels
    func startSimulation() -> Task<Void, Never> {
        Task { [weak self] in
            var time: Double = 0
            while !Task.isCancelled {
                guard let self else { return }

                // Generate simulated waveform data (20 bars)
                var simulatedLevels: [Double] = []
                for i in 0..<20 {
                    let phase = time + Double(i) * 0.3
                    let level = (sin(phase) + 1) * 0.3 + Double.random(in: 0...0.1)
                    simulatedLevels.append(min(level, 1.0))
                }

                self.simulateLevels(simulatedLevels)
                time += 0.1

                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
