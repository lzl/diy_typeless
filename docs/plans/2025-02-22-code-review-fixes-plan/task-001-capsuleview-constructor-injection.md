# Task 001: CapsuleView Constructor Injection

**BDD Scenario**: Scenario 1 - CapsuleView uses constructor injection for AudioLevelMonitor

## Goal

Modify CapsuleView to inject AudioLevelMonitor via constructor instead of creating it directly with @State.

## Acceptance Criteria

- [ ] CapsuleView has an initializer that accepts `audioMonitor: AudioLevelProviding` parameter
- [ ] Default parameter value is `AudioLevelMonitor()` for backward compatibility
- [ ] `@State private var audioMonitor = AudioLevelMonitor()` is removed from view body
- [ ] The injected audioMonitor is stored as a regular property
- [ ] All existing usages of CapsuleView continue to compile

## Files to Modify

- `app/DIYTypeless/DIYTypeless/Capsule/CapsuleView.swift`

## Verification

```bash
./scripts/dev-loop-build.sh --testing
```

Build should pass without errors.

## Dependencies

None

## Commit Boundary

Single commit for this task:
```
refactor(capsule): use constructor injection for audio monitor
```
