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

@MainActor
final class AudioLevelMonitor: AudioLevelProviding {
    private let audioEngine = AVAudioEngine()
    private(set) var levels: [Double] = []

    // Implementation details for audio tap
    // Convert PCM buffer to normalized Double values
    // Use Task.sleep instead of Timer for @MainActor compliance
}
```

## Key Implementation Notes

- **CRITICAL**: Remove Timer usage - use `Task.sleep` instead for Sendable compliance
- Levels must be `[Double]`, convert from PCM buffer values
- Handle audio tap install/uninstall lifecycle
- Support start/stop monitoring methods

## Depends On

- Task 005: Infrastructure Layer - AudioLevelMonitor (Test)

## Verification

```bash
# Run Infrastructure layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
