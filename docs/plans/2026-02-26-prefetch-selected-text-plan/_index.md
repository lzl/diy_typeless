# Implementation Plan: Prefetch Selected Text

## Goal

Implement delayed prefetch of selected text (300ms after Fn key down) to reduce perceived latency when user releases Fn key.

## Design Reference

Based on: [Prefetch Selected Text Design](../2026-02-26-prefetch-selected-text-design/_index.md)

## Architecture

- **New File**: `PrefetchScheduler.swift` - Protocol for time-based scheduling
- **New File**: `RealPrefetchScheduler.swift` - Production scheduler implementation
- **Modified File**: `RecordingState.swift` - Core prefetch logic with injected scheduler
- **Modified File**: `SelectedTextContext.swift` - Add `.empty` static property
- **Test File**: `MockPrefetchScheduler.swift` - Test double for scheduler
- **Test File**: `RecordingStateTests.swift` - Add prefetch test cases

## Constraints

1. All state must be `@MainActor` isolated
2. Task cancellation must be cooperative (check `Task.isCancelled`)
3. Backward compatible - no public API changes
4. 300ms delay must be configurable for testing

## Execution Plan

### Setup
- [Task 001: Add SelectedTextContext.empty](./task-001-add-empty-context.md)

### Infrastructure
- [Task 002: Add PrefetchScheduler protocol and implementations](./task-002-add-scheduler.md)

### Core Prefetch Implementation (Red-Green)
- [Task 003: Test - Normal prefetch flow](./task-003-test-normal-prefetch.md)
- [Task 004: Implement - Normal prefetch flow](./task-004-implement-normal-prefetch.md)

### Short Press Handling (Red-Green)
- [Task 005: Test - Short press cancellation](./task-005-test-short-press.md)
- [Task 006: Implement - Short press handling](./task-006-implement-short-press.md)

### State Cleanup (Red-Green)
- [Task 007: Test - Rapid key presses and cleanup](./task-007-test-cleanup.md)
- [Task 008: Implement - State cleanup](./task-008-implement-cleanup.md)

### Validation
- [Task 009: Build verification and manual validation](./task-009-validation.md)

## Verification Strategy

1. Unit tests cover all BDD scenarios
2. Build passes with `./scripts/dev-loop-build.sh --testing`
3. Manual test: Verify voice command mode starts immediately on Fn up

## Rollback Plan

If issues found, revert changes to `RecordingState.swift` and `SelectedTextContext.swift`.
