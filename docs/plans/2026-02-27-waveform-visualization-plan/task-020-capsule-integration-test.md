# Task 020: Capsule Integration - Tests

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

Create tests for integrating the waveform visualization into the existing Capsule window system.

## Acceptance Criteria

1. Test that waveform appears only in `.recording` state
2. Test that waveform is centered vertically in capsule
3. Test that waveform adapts to capsule width
4. Test 200ms fade-out transition when stopping
5. Test memory cleanup after view disappears
6. Test that waveform doesn't appear in other states
7. Test dependency injection (constructor or @Environment)
8. Test that `AudioLevelMonitor.startMonitoring()` is called on recording start
9. Test that `AudioLevelMonitor.stopMonitoring()` is called on recording stop
10. Test VoiceOver accessibility label "Recording audio"

## Implementation Notes

- Capsule window is managed by `CapsuleWindow.swift`
- State transitions: idle → recording → processing → idle
- Waveform should only appear during recording state
- Use constructor injection or @Environment for `AudioLevelMonitor` and `WaveformSettings`
- CapsuleState should control audio monitoring lifecycle
- Accessibility label: "Recording audio"

## Depends On

- Task 019: Mock Objects and Test Helpers

## Verification

```bash
# Run integration tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail, indicating integration points that need implementation (Red phase).
