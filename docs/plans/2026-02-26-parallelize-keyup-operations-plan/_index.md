# Implementation Plan: Parallelize KeyUp Operations

**Created**: 2026-02-26
**Status**: Draft
**Related Design**: [docs/plans/2026-02-26-parallelize-keyup-operations-design](../2026-02-26-parallelize-keyup-operations-design/)

---

## Goal

Reduce the perceived delay when the user releases the Fn key by parallelizing two independent operations:
- `getSelectedTextUseCase.execute()` - Get selected text via Accessibility API or clipboard
- `stopRecordingUseCase.execute()` - Stop recording and process audio

**Expected improvement**: UI transition delay reduced from `delay1 + delay2` (60-1000ms worst case) to `max(delay1, delay2)` (~50-800ms).

---

## Architecture Overview

### Change Location

**Primary File**: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`
**Method**: `handleKeyUp()`

### Pattern

Use Swift's `async let` for parallel execution:

```
Before (Serial):          After (Parallel):
handleKeyUp()             handleKeyUp()
    ├─ await useCase1         ├─ async let result1
    ├─ await useCase2         ├─ async let result2
    └─ update UI              └─ await (result1, result2)
                              └─ update UI
```

---

## Constraints

1. **Clean Architecture**: Changes limited to Presentation layer (`RecordingState`)
2. **No Domain changes**: UseCase protocols remain unchanged
3. **Generation cancellation**: Must preserve existing cancellation logic
4. **Error handling**: Must preserve existing error handling behavior

---

## Execution Plan

| Task | Description | BDD Scenario | Red/Green |
|------|-------------|--------------|-----------|
| [Task 001: Setup Test Infrastructure](./task-001-setup-test-infrastructure.md) | Create mock use cases and test helpers | Foundation | Infrastructure |
| [Task 002: Test Parallel Execution](./task-002-test-parallel-execution.md) | Write timing test for parallel execution | Scenario 1 | Red |
| [Task 003: Implement Parallel Execution](./task-003-implement-parallel-execution.md) | Use `async let` for concurrent execution | Scenario 1 | Green |
| [Task 004: Test Voice Command Mode](./task-004-test-voice-command-mode.md) | Test voice command with selected text | Scenario 2 | Red |
| [Task 005: Implement Voice Command Mode](./task-005-implement-voice-command-mode.md) | Ensure voice command works with parallel | Scenario 2 | Green |
| [Task 006: Test Error Handling](./task-006-test-error-handling.md) | Test error propagation in parallel | Scenario 3 | Red |
| [Task 007: Implement Error Handling](./task-007-implement-error-handling.md) | Ensure errors handled correctly | Scenario 3 | Green |
| [Task 008: Test Generation Cancellation](./task-008-test-generation-cancellation.md) | Test cancellation with rapid key presses | Scenario 4 | Red |
| [Task 009: Implement Generation Cancellation](./task-009-implement-generation-cancellation.md) | Ensure cancellation works correctly | Scenario 4 | Green |
| [Task 010: Integration and Manual Validation](./task-010-integration-and-manual-validation.md) | Run all tests and manual performance check | All | Validation |

---

## Task Dependencies

```
Task 001 (Setup)
    │
    ├── Task 002 (Red: Parallel Test) ──┐
    │                                   ├── Task 003 (Green: Parallel Impl)
    ├── Task 004 (Red: Voice Command) ──┤
    │                                   ├── Task 005 (Green: Voice Command)
    ├── Task 006 (Red: Error Test) ─────┤
    │                                   ├── Task 007 (Green: Error Handling)
    ├── Task 008 (Red: Cancellation) ───┤
    │                                   ├── Task 009 (Green: Cancellation)
    │
    └── Task 010 (Integration) - depends on all above
```

**Note**: Tasks 002, 004, 006, and 008 are independent "Red" test tasks that can be written in parallel after Task 001. Each Red task is paired with its corresponding Green implementation task.

---

## Verification Strategy

### Automated Tests

- **Unit tests**: Mock use cases with controlled delays
- **Timing tests**: Assert `max(delay1, delay2)` not `delay1 + delay2`
- **Error tests**: Verify error propagation and state
- **Cancellation tests**: Verify generation-based invalidation

### Manual Tests

- Perceived performance: Release Fn key, time UI transition
- Voice command mode: Select text, verify capture
- Rapid cancellation: Quick Fn up/down cycles

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `async let` behaves differently than expected | Test with known delays first |
| Error propagation lost in tuple | Verify both error paths in tests |
| Generation check in wrong place | Preserve existing pattern after parallel await |
| MainActor isolation issues | Ensure mocks are `@MainActor` compatible |

---

## Out of Scope

- Changes to UseCase protocols or implementations
- UI redesign or new states
- Accessibility API changes
- Audio recording pipeline changes

---

## References

- [Design Document](../2026-02-26-parallelize-keyup-operations-design/_index.md)
- [BDD Specifications](../2026-02-26-parallelize-keyup-operations-design/bdd-specs.md)
