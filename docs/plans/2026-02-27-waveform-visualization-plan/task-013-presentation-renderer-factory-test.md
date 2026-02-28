# Task 013: Presentation Layer - WaveformRendererFactory (Test)

## BDD Scenario

```gherkin
Scenario: Style can be selected at runtime
  Given multiple waveform styles are available
  When the application requests a specific style by identifier
  Then the WaveformRendererFactory should return the correct renderer
  And the renderer should be cached in @State
  And the waveform view should immediately switch to the new style
  And the transition should be smooth without visual artifacts
```

```gherkin
Scenario: Default style is Fluid Waveform
  Given the waveform visualization is initialized
  When no specific style has been selected
  Then the default style should be Fluid Waveform
  And the default renderer should be FluidWaveformRenderer
  And the FluidWaveformRenderer should maintain smoothing state
```

## Description

Create tests for the `WaveformRendererFactory`. This factory creates renderers from `WaveformStyle` enum values.

## Acceptance Criteria

1. Test that `WaveformRendererFactory` exists in `Presentation/Waveform/WaveformRendererFactory.swift`
2. Test that `.fluid` returns `FluidWaveformRenderer`
3. Test that `.bars` returns `BarWaveformRenderer`
4. Test that `.disabled` returns `nil`
5. Test that factory is `@MainActor`
6. Test that returned renderers are `WaveformRendering` instances

## Implementation Notes

- Factory must be `@MainActor` because it creates `@MainActor` classes
- Use static methods for factory pattern
- Return type should be `WaveformRendering?` (optional for disabled)

## Depends On

- Task 012: Presentation Layer - BarWaveformRenderer (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "WaveformRendererFactory not found" or similar error (Red phase).
