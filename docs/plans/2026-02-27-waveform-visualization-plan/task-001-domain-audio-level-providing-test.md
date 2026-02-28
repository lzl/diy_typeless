# Task 001: Domain Layer - AudioLevelProviding Protocol (Test)

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

Create tests for the `AudioLevelProviding` protocol in the Domain layer. This protocol must use pure Swift types only (`Double`, not `CGFloat`) and must not import any UI or audio frameworks (SwiftUI, AVFoundation).

## Acceptance Criteria

1. Test that `AudioLevelProviding` protocol exists in `Domain/Protocols/AudioLevelProviding.swift`
2. Test that the protocol exposes `levels: [Double]` property
3. Test that the protocol does not use `CGFloat`
4. Test that the Domain layer file has no SwiftUI imports
5. Test that the Domain layer file has no AVFoundation imports

## Implementation Notes

- Use protocol-oriented design to allow mocking in tests
- The protocol should be `Sendable` for concurrency safety
- File location: `DIYTypeless/Domain/Protocols/AudioLevelProviding.swift`

## Depends On

None - This is the foundation task.

## Verification

```bash
# Run Domain layer tests
./scripts/dev-loop-build.sh --testing
```

Expected: Tests should fail with "AudioLevelProviding not found" or similar error (Red phase).
