# Task 005: Infrastructure Layer - AudioLevelMonitor (Test)

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

Create tests for the `AudioLevelMonitor` in the Infrastructure layer. This component implements `AudioLevelProviding` using AVAudioEngine to capture real-time audio levels.

## Acceptance Criteria

1. Test that `AudioLevelMonitor` exists in `Infrastructure/Audio/AudioLevelMonitor.swift`
2. Test that it conforms to `AudioLevelProviding`
3. Test that it publishes levels as `[Double]` via `AsyncStream`
4. Test that levels are normalized to 0.0...1.0 range
5. Test that it handles audio interruption gracefully
6. Test proper isolation (actor-isolated, NOT @MainActor)
7. Test that `nonisolated` methods allow AVAudioEngine tap callbacks
8. Test that AsyncStream properly emits level updates

## Mock Strategy

Create a mock for testing:

```swift
actor MockAudioLevelMonitor: AudioLevelProviding {
    private(set) var levels: [Double] = []
    private var continuation: AsyncStream<[Double]>.Continuation?

    var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func simulateLevels(_ newLevels: [Double]) {
        levels = newLevels
        continuation?.yield(newLevels)
    }
}
```

## Depends On

- Task 004: Domain Layer - WaveformStyle Enum (Implementation)

## Verification

```bash
# Run Infrastructure layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "AudioLevelMonitor not found" or similar error (Red phase).
