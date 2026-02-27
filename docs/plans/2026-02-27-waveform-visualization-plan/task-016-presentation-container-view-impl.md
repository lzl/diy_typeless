# Task 016: Presentation Layer - WaveformContainerView (Implementation)

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

## Description

Implement the `WaveformContainerView`. This SwiftUI view combines `TimelineView` + `Canvas` for 60fps GPU-accelerated waveform rendering.

## Acceptance Criteria

1. Create `Presentation/Waveform/WaveformContainerView.swift`
2. Use `TimelineView(.animation)` for v-sync updates
3. Use `Canvas` for GPU rendering
4. Cache renderer in `@State` (CRITICAL - not recreated each frame)
5. Accept `AudioLevelProviding` and `WaveformStyle` via constructor
6. Support SwiftUI Preview with mock data
7. All tests from Task 015 pass

## Files to Create/Modify

- `DIYTypeless/Presentation/Waveform/WaveformContainerView.swift` (create)

## Implementation Sketch

```swift
import SwiftUI

struct WaveformContainerView: View {
    private let audioProvider: AudioLevelProviding
    private let style: WaveformStyle

    @State private var renderer: WaveformRendering?

    init(
        audioProvider: AudioLevelProviding,
        style: WaveformStyle = .fluid
    ) {
        self.audioProvider = audioProvider
        self.style = style
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                renderer?.render(
                    context: context,
                    size: size,
                    levels: audioProvider.levels,
                    time: timeline.date
                )
            }
        }
        .onAppear {
            if renderer == nil {
                renderer = WaveformRendererFactory.makeRenderer(for: style)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WaveformContainerView(
        audioProvider: MockAudioLevelProvider(),
        style: .fluid
    )
    .frame(width: 200, height: 40)
}
```

## Key Implementation Notes

- **CRITICAL**: Renderer is cached in `@State` and only created in `.onAppear`
- **CRITICAL**: Do NOT create renderer in Canvas closure (that would recreate every frame)
- TimelineView provides `timeline.date` for animation phase
- Canvas closure runs on GPU, not main thread

## Depends On

- Task 015: Presentation Layer - WaveformContainerView (Test)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
