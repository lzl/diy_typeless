# Task 008: Presentation Layer - WaveformRendering Protocol (Implementation)

## BDD Scenario

```gherkin
Scenario: WaveformRendering protocol is in Presentation layer
  Given the WaveformRendering protocol is defined
  When I check its file location
  Then it should be in the Presentation/Protocols directory
  And it should use GraphicsContext (SwiftUI type)
  And it should NOT be in Domain layer
  And Domain layer should have no SwiftUI imports
```

## Description

Implement the `WaveformRendering` protocol in the Presentation layer. This protocol defines how waveform renderers draw using SwiftUI's Canvas and GraphicsContext.

## Acceptance Criteria

1. Create `Presentation/Protocols/WaveformRendering.swift`
2. Protocol uses `GraphicsContext` from SwiftUI
3. Protocol has render method with signature:
   `func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date)`
4. Protocol is marked `@MainActor`
5. All tests from Task 007 pass

## Files to Create/Modify

- `DIYTypeless/Presentation/Protocols/WaveformRendering.swift` (create)

## Implementation Sketch

```swift
import SwiftUI

/// Protocol for waveform renderers that draw using SwiftUI Canvas
/// Uses GraphicsContext - MUST be in Presentation layer
@MainActor
protocol WaveformRendering: AnyObject {
    /// Render the waveform into the provided graphics context
    /// - Parameters:
    ///   - context: The GraphicsContext to draw into
    ///   - size: The available size for rendering
    ///   - levels: Audio levels as normalized Double values (0...1)
    ///   - time: Current animation time for phase calculations
    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    )
}
```

## Depends On

- Task 007: Presentation Layer - WaveformRendering Protocol (Test)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
