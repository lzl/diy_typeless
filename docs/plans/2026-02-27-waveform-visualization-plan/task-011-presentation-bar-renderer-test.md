# Task 011: Presentation Layer - BarWaveformRenderer (Test)

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
Scenario: Renderer handles empty levels gracefully
  Given the waveform is rendering
  When the levels array is empty
  Then the renderer should return early without crashing
  And the Canvas should remain empty
  And no exception should be thrown
```

## Description

Create tests for the `BarWaveformRenderer` class. This is the legacy bar-style renderer that provides backward compatibility with the existing design.

## Acceptance Criteria

1. Test that `BarWaveformRenderer` is a `@MainActor class` (NOT struct)
2. Test that it conforms to `WaveformRendering`
3. Test that it renders discrete bars
4. Test graceful handling of empty levels array
5. Test bar height reflects audio level
6. Test minimum bar height for silence

## Implementation Notes

- This is the "legacy" style for users who prefer the current look
- Should match current aesthetic: rounded rectangles, accent color
- Bars should have consistent spacing

## Depends On

- Task 010: Presentation Layer - FluidWaveformRenderer (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "BarWaveformRenderer not found" or similar error (Red phase).
