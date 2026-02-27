# Task 012: Presentation Layer - BarWaveformRenderer (Implementation)

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

## Description

Implement the `BarWaveformRenderer` class. This is the legacy bar-style renderer for users who prefer the discrete bar aesthetic.

## Acceptance Criteria

1. Create `Presentation/Waveform/BarWaveformRenderer.swift`
2. Must be `@MainActor final class` (not struct)
3. Conform to `WaveformRendering`
4. Render discrete rounded bars
5. Use `Color.accentColor` for consistency
6. Add spacing between bars
7. Minimum height for silence
8. All tests from Task 011 pass

## Files to Create/Modify

- `DIYTypeless/Presentation/Waveform/BarWaveformRenderer.swift` (create)

## Implementation Sketch

```swift
import SwiftUI

@MainActor
final class BarWaveformRenderer: WaveformRendering {
    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        let barCount = levels.count
        let spacing: CGFloat = 4
        let barWidth = (size.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount)
        let maxBarHeight = size.height

        for (index, level) in levels.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            let barHeight = max(4, level * Double(maxBarHeight)) // Min 4pt height
            let y = (size.height - CGFloat(barHeight)) / 2

            let rect = CGRect(x: x, y: y, width: barWidth, height: CGFloat(barHeight))
            let path = Path(roundedRect: rect, cornerRadius: 2)

            context.fill(path, with: .color(.accentColor))
        }
    }
}
```

## Depends On

- Task 011: Presentation Layer - BarWaveformRenderer (Test)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
