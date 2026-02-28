# Task 007: Presentation Layer - WaveformRendering Protocol (Test)

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

Create tests for the `WaveformRendering` protocol in the Presentation layer. This protocol uses SwiftUI's `GraphicsContext` and must not be in the Domain layer.

## Acceptance Criteria

1. Test that `WaveformRendering` protocol exists in `Presentation/Protocols/WaveformRendering.swift`
2. Test that it uses `GraphicsContext` (SwiftUI type)
3. Test that render method signature accepts `GraphicsContext`, `CGSize`, `[Double]`, and `Date` (time)
4. Test that the protocol is `@MainActor`
5. Test that Domain layer has no SwiftUI imports

## Implementation Notes

- This protocol BELONGS in Presentation layer because it uses GraphicsContext
- The render method signature:
  ```swift
  func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date)
  ```
- Must be `@MainActor` because GraphicsContext is MainActor-bound

## Depends On

- Task 006: Infrastructure Layer - AudioLevelMonitor (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "WaveformRendering not found" or similar error (Red phase).
