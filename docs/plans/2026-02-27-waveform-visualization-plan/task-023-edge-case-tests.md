# Task 023: Edge Case Tests

## BDD Scenario

```gherkin
Scenario: Waveform displays when audio level is zero
  Given the microphone is muted or no audio is detected
  When the waveform is displayed
  Then all bars should show minimum height (not disappear completely)
  And the waveform should indicate "silence" visually
  And the animation should continue (not freeze)
  And the smoothing algorithm should handle zero values
```

```gherkin
Scenario: Waveform handles maximum audio level gracefully
  Given the audio input is at maximum level (clipping)
  When the waveform renders
  Then bars should cap at maximum display height
  And the waveform should not overflow its container
  And no exception should be thrown
  And values should be clamped to valid range
```

```gherkin
Scenario: Waveform recovers from audio interruption
  Given the waveform is actively animating
  When the audio session is interrupted (e.g., phone call, Siri)
  Then the waveform should pause gracefully
  And when the interruption ends
  Then the waveform should resume animation automatically
  And the renderer state should be preserved
```

```gherkin
Scenario: Renderer handles rapid style switches
  Given the waveform is rendering with Fluid style
  When the user rapidly switches between styles 10 times
  Then each switch should complete successfully
  And memory usage should not increase
  And only the current renderer should be retained
```

## Description

Create comprehensive edge case tests to ensure the waveform system is robust.

## Test Cases

1. **Silence**: All levels = 0.0
2. **Maximum**: All levels = 1.0
3. **Empty**: Levels array is empty
4. **Rapid alternation**: [0.0, 1.0, 0.0, 1.0, ...]
5. **Large array**: 1000+ levels
6. **NaN/Infinity**: Invalid Double values
7. **Audio interruption**: Simulate AVAudioSession interruption
8. **Rapid style switching**: Switch 10 times in 1 second
9. **Memory pressure**: Simulate low memory warning

## Files to Create

- `DIYTypelessTests/EdgeCases/WaveformEdgeCaseTests.swift` (create)

## Implementation Sketch

```swift
final class WaveformEdgeCaseTests: XCTestCase {
    func testSilenceLevels() throws {
        let renderer = FluidWaveformRenderer()
        let levels: [Double] = [0.0, 0.0, 0.0]
        // Verify minimum height bars rendered, no crash
    }

    func testMaximumLevels() throws {
        let levels: [Double] = [1.0, 1.0, 1.0]
        // Verify clamping, no overflow
    }

    func testEmptyLevels() throws {
        let levels: [Double] = []
        // Verify graceful handling, early return
    }

    func testInvalidValues() throws {
        let levels: [Double] = [.nan, .infinity, -.infinity]
        // Verify graceful handling
    }

    func testRapidStyleSwitching() throws {
        // Switch 10 times, verify no memory growth
    }
}
```

## Depends On

- Task 022: Performance Verification

## Verification

```bash
# Run edge case tests
./scripts/dev-loop-build.sh --testing
```

Expected: All edge cases handled gracefully, no crashes.
