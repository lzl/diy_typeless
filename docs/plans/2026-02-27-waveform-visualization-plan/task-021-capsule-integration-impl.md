# Task 021: Capsule Integration - Implementation

## BDD Scenario

```gherkin
Scenario: Waveform displays in capsule during recording state
  Given the app is in idle state showing the capsule
  When the user initiates recording
  Then the capsule should transition to recording state
  And the waveform visualization should appear inside the capsule
  And the waveform should be centered vertically in the capsule
  And the waveform width should adapt to capsule size
```

```gherkin
Scenario: Waveform transitions smoothly when recording stops
  Given the waveform is actively animating in the capsule
  When the user stops recording
  Then the waveform should fade out over 200ms
  And the capsule should transition to processing state
  And the renderer should not leak memory after transition
```

## Description

Integrate the waveform visualization into the existing Capsule window system. Replace the legacy HStack-based waveform with the new Canvas-based implementation.

## Acceptance Criteria

1. Modify Capsule view to use `WaveformContainerView` during recording
2. Show waveform only in `.recording` state
3. Center waveform vertically in capsule
4. Implement 200ms fade-out on stop
5. Ensure proper memory cleanup (renderer deallocation)
6. Add accessibility label for VoiceOver
7. All tests from Task 020 pass

## Files to Modify

- `DIYTypeless/Capsule/CapsuleView.swift` (modify - integrate waveform)
- `DIYTypeless/Capsule/CapsuleWindow.swift` (review - ensure compatibility)

## Implementation Sketch

```swift
// In CapsuleView.swift, replace legacy waveform with:

@ViewBuilder
private var waveformSection: some View {
    if case .recording = state {
        WaveformContainerView(
            audioProvider: audioLevelMonitor,
            style: waveformSettings.selectedStyle
        )
        .frame(height: 40)
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }
}
```

## Integration Points

1. Inject `AudioLevelMonitor` into CapsuleView/CapsuleState
2. Inject `WaveformSettings` for style configuration
3. Ensure state machine properly starts/stops audio monitoring
4. Handle cleanup when capsule closes

## Depends On

- Task 020: Capsule Integration - Tests

## Verification

```bash
# Run full test suite
./scripts/dev-loop-build.sh --testing

# Verify app builds
./scripts/dev-loop-build.sh
```

Expected: All tests pass, app builds successfully (Green phase).
