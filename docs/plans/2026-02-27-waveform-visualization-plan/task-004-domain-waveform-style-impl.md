# Task 004: Domain Layer - WaveformStyle Enum (Implementation)

## BDD Scenario

```gherkin
Scenario: WaveformStyle is Sendable
  Given the WaveformStyle enum is defined
  When I check its conformance
  Then it should conform to Sendable
  And it should be safe to pass between actors
  And all associated values should be Sendable
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

Implement the `WaveformStyle` enum in the Domain layer. This enum defines the available waveform visualization styles.

## Acceptance Criteria

1. Create `Domain/Entities/WaveformStyle.swift`
2. Enum cases: `.fluid`, `.bars`, `.disabled`
3. Conform to: `String`, `CaseIterable`, `Sendable`
4. Raw values: `"fluid"`, `"bars"`, `"disabled"`
5. Add `displayName` computed property for UI
6. All tests from Task 003 pass

## Files to Create/Modify

- `DIYTypeless/Domain/Entities/WaveformStyle.swift` (create)

## Implementation Sketch

```swift
import Foundation

/// Defines the available waveform visualization styles
enum WaveformStyle: String, CaseIterable, Sendable {
    case fluid = "fluid"
    case bars = "bars"
    case disabled = "disabled"

    var displayName: String {
        switch self {
        case .fluid: return "Fluid"
        case .bars: return "Bars"
        case .disabled: return "Disabled"
        }
    }
}
```

## Depends On

- Task 003: Domain Layer - WaveformStyle Enum (Test)

## Verification

```bash
# Run Domain layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: All tests pass (Green phase).
