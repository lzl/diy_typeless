# Task 015: Presentation Layer - WaveformContainerView (Test)

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
Scenario: Waveform animates smoothly at 60fps
  Given the waveform is active
  When audio levels are changing continuously
  Then the animation should maintain 60 frames per second
  And the TimelineView should drive the animation updates
  And no individual frame should take longer than 16.67ms to render
  And the renderer state should persist across frames
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

Create tests for the `WaveformContainerView`. This is the main SwiftUI view that uses `TimelineView` + `Canvas` for GPU-accelerated rendering.

## Acceptance Criteria

1. Test that `WaveformContainerView` exists in `Presentation/Waveform/WaveformContainerView.swift`
2. Test that it uses `TimelineView` for animation scheduling
3. Test that it uses `Canvas` for rendering
4. Test that renderer is cached in `@State` (not recreated each frame)
5. Test that it accepts an `AudioLevelProviding` dependency
6. Test that preview uses `MockAudioLevelProvider`

## Implementation Notes

- **CRITICAL**: Renderer must be cached in `@State`:
  ```swift
  @State private var renderer: WaveformRendering?
  ```
- Must NOT create new renderer in Canvas closure
- Must use `.onAppear` to initialize renderer once

## Depends On

- Task 014: Presentation Layer - WaveformRendererFactory (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "WaveformContainerView not found" or similar error (Red phase).
