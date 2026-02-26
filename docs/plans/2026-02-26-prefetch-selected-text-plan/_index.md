# Implementation Plan: Prefetch Selected Text

## Goal

Implement delayed prefetch of selected text (300ms after Fn key down) to reduce perceived latency when user releases Fn key.

## Design Reference

Based on: [Prefetch Selected Text Design](../2026-02-26-prefetch-selected-text-design/_index.md)

## Architecture

- **Modified File**: `RecordingState.swift` - Core prefetch logic
- **Modified File**: `SelectedTextContext.swift` - Add `.empty` static property
- **Test File**: `RecordingStateTests.swift` - Add prefetch test cases

## Constraints

1. All state must be `@MainActor` isolated
2. Task cancellation must be cooperative (check `Task.isCancelled`)
3. Backward compatible - no public API changes
4. 300ms delay must be configurable for testing

## Execution Plan

### Setup
- [Task 001: Add SelectedTextContext.empty](./task-001-add-empty-context.md)

### Core Prefetch Implementation (Red-Green)
- [Task 002: Test - Normal prefetch flow](./task-002-test-normal-prefetch.md)
- [Task 003: Implement - Normal prefetch flow](./task-003-implement-normal-prefetch.md)

### Short Press Handling (Red-Green)
- [Task 004: Test - Short press cancellation](./task-004-test-short-press.md)
- [Task 005: Implement - Short press handling](./task-005-implement-short-press.md)

### State Cleanup (Red-Green)
- [Task 006: Test - Rapid key presses and cleanup](./task-006-test-cleanup.md)
- [Task 007: Implement - State cleanup](./task-007-implement-cleanup.md)

### Validation
- [Task 008: Build verification and manual validation](./task-008-validation.md)

## Verification Strategy

1. Unit tests cover all BDD scenarios
2. Build passes with `./scripts/dev-loop.sh --testing`
3. Manual test: Verify voice command mode starts immediately on Fn up

## Rollback Plan

If issues found, revert changes to `RecordingState.swift` and `SelectedTextContext.swift`.
