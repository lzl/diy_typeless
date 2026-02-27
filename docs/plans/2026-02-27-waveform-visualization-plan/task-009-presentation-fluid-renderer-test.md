# Task 009: Presentation Layer - FluidWaveformRenderer (Test)

## BDD Scenario

```gherkin
Scenario: Multiple waveform styles are supported
  Given the waveform style architecture is implemented
  When a new style is added conforming to WaveformRendering protocol
  Then the system should recognize the new style
  And the style should be a @MainActor class (not struct)
  And existing styles should remain unaffected
  And the style enum should be Sendable for concurrency safety
```

```gherkin
Scenario: Renderer state persists across frames
  Given a FluidWaveformRenderer is active
  When multiple animation frames are rendered
  Then the smoothedLevels array should maintain values between frames
  And the renderer should be the same instance (not recreated)
  And exponential smoothing should produce gradual transitions
```

```gherkin
Scenario: Renderer handles empty levels gracefully
  Given the waveform is rendering
  When the levels array is empty
  Then the renderer should return early without crashing
  And the Canvas should remain empty
  And no exception should be thrown
```

## Description

Create tests for the `FluidWaveformRenderer` class. This is the Siri-like fluid waveform renderer that must maintain state across animation frames.

## Acceptance Criteria

1. Test that `FluidWaveformRenderer` is a `@MainActor class` (NOT struct)
2. Test that it conforms to `WaveformRendering`
3. Test that `smoothedLevels` array maintains values between render calls
4. Test exponential smoothing formula produces expected values
5. Test graceful handling of empty levels array
6. Test three-layer sine wave formula
7. Test minimum height for silence (not zero)

## Test Data

```swift
let testLevels: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0, 0.8, 0.6, 0.4, 0.2, 0.1]
let emptyLevels: [Double] = []
let silenceLevels: [Double] = [0.0, 0.0, 0.0]
let maxLevels: [Double] = [1.0, 1.0, 1.0]
```

## Depends On

- Task 008: Presentation Layer - WaveformRendering Protocol (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "FluidWaveformRenderer not found" or similar error (Red phase).
