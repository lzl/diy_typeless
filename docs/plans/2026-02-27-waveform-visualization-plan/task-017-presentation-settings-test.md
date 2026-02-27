# Task 017: Presentation Layer - WaveformSettings (Test)

## BDD Scenario

```gherkin
Scenario: @Observable without didSet
  Given WaveformSettings uses @Observable
  When properties are observed
  Then it should NOT use didSet observers
  And it should use computed properties for side effects
  And state updates should propagate automatically
```

## Description

Create tests for `WaveformSettings`, an `@Observable` class that manages waveform configuration. Must NOT use `didSet` (anti-pattern with @Observable).

## Acceptance Criteria

1. Test that `WaveformSettings` exists in `Presentation/Settings/WaveformSettings.swift`
2. Test that it uses `@Observable` (not ObservableObject)
3. Test that it does NOT use `didSet` (anti-pattern)
4. Test that it uses computed property with get/set for UserDefaults
5. Test that `selectedStyle` property works with `WaveformStyle`

## Implementation Notes

- `@Observable` with `didSet` is an anti-pattern - properties trigger updates automatically
- Use computed properties with explicit get/set for UserDefaults persistence
- Must be `@MainActor` because it's used by SwiftUI views

## Depends On

- Task 016: Presentation Layer - WaveformContainerView (Implementation)

## Verification

```bash
# Run Presentation layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "WaveformSettings not found" or similar error (Red phase).
