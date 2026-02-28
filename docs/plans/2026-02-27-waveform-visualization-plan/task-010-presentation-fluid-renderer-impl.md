# Task 010: Presentation Layer - FluidWaveformRenderer (Implementation)

## BDD Scenario

```gherkin
Scenario: Display fluid waveform during recording
  When the user starts recording audio
  Then the waveform visualization should appear in the capsule
  And the waveform should use Canvas-based rendering
  And the waveform should use TimelineView for 60fps animation
  And the renderer should be cached to maintain animation state
```

```gherkin
Scenario: Renderer state persists across frames
  Given a FluidWaveformRenderer is active
  When multiple animation frames are rendered
  Then the smoothedLevels array should maintain values between frames
  And the renderer should be the same instance (not recreated)
  And exponential smoothing should produce gradual transitions
```

## Description

Implement the `FluidWaveformRenderer` class. This is a `@MainActor class` (NOT struct) that implements the Siri-like fluid waveform using three-layer sine wave叠加.

## Acceptance Criteria

1. Create `Presentation/Waveform/FluidWaveformRenderer.swift`
2. Must be `@MainActor final class` (not struct)
3. Conform to `WaveformRendering`
4. Maintain `smoothedLevels: [Double]` state across frames
5. Implement exponential smoothing (alpha ~0.3)
6. Implement three-layer sine wave formula
7. Use semantic colors (`Color.primary` not `.white`)
8. Handle edge cases (empty array, silence, max levels)
9. All tests from Task 009 pass

## Files to Create/Modify

- `DIYTypeless/Presentation/Waveform/FluidWaveformRenderer.swift` (create)

## Implementation Sketch

```swift
import SwiftUI

@MainActor
final class FluidWaveformRenderer: WaveformRendering {
    private var smoothedLevels: [Double] = []
    private let smoothingAlpha: Double = 0.3

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        // Initialize smoothedLevels if needed
        if smoothedLevels.isEmpty {
            smoothedLevels = Array(repeating: 0.0, count: levels.count)
        }

        // Apply exponential smoothing
        for i in levels.indices {
            smoothedLevels[i] = smoothingAlpha * levels[i] +
                               (1 - smoothingAlpha) * smoothedLevels[i]
        }

        // Three-layer sine wave rendering
        // Primary: sin(x * freq1 + phase1) * amplitude1
        // Secondary: sin(x * freq2 + phase2) * amplitude2 * 0.5
        // Tertiary: sin(x * freq3 + time * 0.5) * amplitude3 * 0.3

        // Use Color.primary for semantic color support
    }
}
```

## Depends On

- Task 009: Presentation Layer - FluidWaveformRenderer (Test)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
