# Task 002: Domain Layer - AudioLevelProviding Protocol (Implementation)

## BDD Scenario

```gherkin
Scenario: Domain layer remains pure
  Given the Domain layer contains waveform-related code
  When I check for framework dependencies
  Then there should be no SwiftUI imports
  And there should be no AVFoundation imports
  And there should be no CoreGraphics (CGFloat) usage
  And only standard library types should be used (Double, not CGFloat)
```

```gherkin
Scenario: Domain layer uses Double (not CGFloat)
  Given the AudioLevelProviding protocol is defined
  When I check the levels array type
  Then it should be [Double]
  And it should NOT be [CGFloat]
  And calculations should use Double throughout Domain layer
```

## Description

Implement the `AudioLevelProviding` protocol in the Domain layer. This is a pure protocol with no external dependencies that defines how audio levels are provided to the waveform visualization.

## Acceptance Criteria

1. Create `Domain/Protocols/AudioLevelProviding.swift`
2. Protocol must expose `var levels: [Double] { get }`
3. Protocol must be `Sendable`
4. No imports except `Foundation`
5. All tests from Task 001 pass

## Files to Create/Modify

- `DIYTypeless/Domain/Protocols/AudioLevelProviding.swift` (create)

## Implementation Sketch

```swift
import Foundation

/// Protocol for providing audio level data to waveform visualizations
/// Uses Double (not CGFloat) to maintain Domain layer purity
protocol AudioLevelProviding: Sendable {
    /// Current audio levels as normalized values (0.0...1.0)
    var levels: [Double] { get }
}
```

## Depends On

- Task 001: Domain Layer - AudioLevelProviding Protocol (Test)

## Verification

```bash
# Run Domain layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
