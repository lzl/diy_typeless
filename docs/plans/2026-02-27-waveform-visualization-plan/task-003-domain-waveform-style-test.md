# Task 003: Domain Layer - WaveformStyle Enum (Test)

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

Create tests for the `WaveformStyle` enum in the Domain layer. This enum must be `Sendable` for concurrency safety and support UserDefaults persistence via `RawRepresentable`.

## Acceptance Criteria

1. Test that `WaveformStyle` enum exists in `Domain/Entities/WaveformStyle.swift`
2. Test that enum has cases: `.fluid`, `.bars`, `.disabled`
3. Test that enum is `Sendable`
4. Test that enum is `String` backed with `RawRepresentable`
5. Test that enum is `CaseIterable`
6. Test that default case is `.fluid`

## Implementation Notes

- Enum must be in Domain layer (Entities)
- Use `String` raw values for UserDefaults compatibility
- Must work with `@AppStorage` when used in Presentation layer

## Depends On

- Task 002: Domain Layer - AudioLevelProviding Protocol (Implementation)

## Verification

```bash
# Run Domain layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "WaveformStyle not found" or similar error (Red phase).
