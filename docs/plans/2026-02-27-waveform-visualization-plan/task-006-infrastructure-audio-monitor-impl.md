# Task 006: Infrastructure Layer - AudioLevelMonitor (Implementation)

## BDD Scenario

```gherkin
Scenario: AudioLevelMonitor is in Infrastructure layer
  Given the AudioLevelMonitor implementation exists
  When I check its file location
  Then it should be in the Infrastructure/Audio directory
  And it should use AVAudioEngine
  And it should conform to AudioLevelProviding protocol
  And it should be marked as @MainActor or use proper isolation
```

```gherkin
Scenario: Waveform responds to audio levels in real-time
  Given the waveform is displayed
  When the AudioLevelMonitor publishes a new audio level
  Then the waveform bars should update within 50ms
  And the bar heights should reflect the amplitude of the audio signal
  And the update should not cause frame drops or stuttering
  And the waveform should use Double (not CGFloat) for level calculations
```

## Description

Implement the `AudioLevelMonitor` in the Infrastructure layer. This component uses AVAudioEngine to capture real-time audio levels and exposes them via the `AudioLevelProviding` protocol.

## Acceptance Criteria

1. Create `Infrastructure/Audio/AudioLevelMonitor.swift`
2. Implement `AudioLevelProviding` protocol
3. Use `AVAudioEngine` for audio capture
4. Normalize levels to 0.0...1.0 range
5. Publish levels using observation pattern (for SwiftUI integration)
6. Handle audio session interruptions
7. All tests from Task 005 pass

## Files to Create/Modify

- `DIYTypeless/Infrastructure/Audio/AudioLevelMonitor.swift` (create)

## Implementation Sketch

```swift
import AVFoundation

/// Actor-isolated audio level monitor that bridges AVAudioEngine to SwiftUI
/// Uses AsyncStream for safe cross-actor communication
actor AudioLevelMonitor {
    private let audioEngine = AVAudioEngine()
    private var continuation: AsyncStream<[Double]>.Continuation?

    /// AsyncStream that emits audio levels - safe for SwiftUI observation
    var levelsStream: AsyncStream<[Double]> {
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

    func stopMonitoring() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        continuation?.finish()
        continuation = nil
    }

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

// MARK: - AudioLevelProviding Conformance

extension AudioLevelMonitor: AudioLevelProviding {
    /// Current audio levels - used for synchronous access
    /// For real-time UI, prefer `levelsStream`
    nonisolated var levels: [Double] {
        // Return empty array for synchronous access
        // Real-time updates come through levelsStream
        []
    }
}
```

## Key Implementation Notes

- **CRITICAL**: Use `actor` (not @MainActor) since AVAudioEngine callbacks are on background threads
- **CRITICAL**: Use `AsyncStream` for safe cross-actor communication to SwiftUI views
- `nonisolated` methods allow AVAudioEngine tap callback to call actor methods
- Levels are `[Double]`, normalized to 0.0...1.0 range
- Handle audio tap install/uninstall lifecycle
- Supports both stream-based (preferred) and synchronous access

## Usage in SwiftUI

```swift
struct WaveformContainerView: View {
    let audioMonitor: AudioLevelMonitor
    @State private var levels: [Double] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                renderer?.render(context: context, size: size, levels: levels, time: timeline.date)
            }
        }
        .task {
            // Subscribe to level updates via AsyncStream
            for await newLevels in await audioMonitor.levelsStream {
                levels = newLevels
            }
        }
    }
}
```

## Depends On

- Task 005: Infrastructure Layer - AudioLevelMonitor (Test)

## Verification

```bash
# Run Infrastructure layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
