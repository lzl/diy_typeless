# Task 014: Presentation Layer - WaveformRendererFactory (Implementation)

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

## Description

Implement the `WaveformRendererFactory`. This factory creates the appropriate renderer instances based on `WaveformStyle`.

## Acceptance Criteria

1. Create `Presentation/Waveform/WaveformRendererFactory.swift`
2. Must be `@MainActor`
3. Static method: `makeRenderer(for style: WaveformStyle) -> WaveformRendering?`
4. Return `FluidWaveformRenderer()` for `.fluid`
5. Return `BarWaveformRenderer()` for `.bars`
6. Return `nil` for `.disabled`
7. All tests from Task 013 pass

## Files to Create/Modify

- `DIYTypeless/Presentation/Waveform/WaveformRendererFactory.swift` (create)

## Implementation Sketch

```swift
import SwiftUI

@MainActor
enum WaveformRendererFactory {
    static func makeRenderer(for style: WaveformStyle) -> WaveformRendering? {
        switch style {
        case .fluid:
            return FluidWaveformRenderer()
        case .bars:
            return BarWaveformRenderer()
        case .disabled:
            return nil
        }
    }
}
```

## Depends On

- Task 013: Presentation Layer - WaveformRendererFactory (Test)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
