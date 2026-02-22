# Code Review Fixes Plan

## Goal

Fix 6 architecture issues identified by SwiftUI Clean Architecture Reviewer to ensure full compliance with Clean Architecture principles.

## Architecture Constraints

- Maintain @MainActor @Observable pattern
- No ObservableObject or @Published allowed
- ViewModels must not contain animation state
- Dependency direction: Presentation → Domain → Data

## Execution Plan

### Phase 1: Constructor Injection Fix
- [Task 001: CapsuleView Constructor Injection](./task-001-capsuleview-constructor-injection.md)

### Phase 2: Design System Improvements
- [Task 002: Semantic Colors for Dark/Light Mode](./task-002-semantic-colors-dark-light-mode.md)

### Phase 3: Error Handling and Robustness
- [Task 003: WaveformView Error Logging](./task-003-waveform-error-logging.md)
- [Task 004: Timer RunLoop Common Mode](./task-004-timer-runloop-common-mode.md)

### Phase 4: Architecture Layer Organization
- [Task 005: Move AudioLevelProviding to Domain Layer](./task-005-move-protocol-to-domain.md)
- [Task 006: Separate Mock to PreviewSupport](./task-006-separate-mock-to-previewsupport.md) (depends on Task 001)

## BDD Scenarios

Refer to [Design Document](../2025-02-22-code-review-fixes-design/bdd-specs.md) for all 6 acceptance scenarios.

## Verification

Run after each task:

```bash
./scripts/dev-loop.sh --testing
```

After all tasks complete:
1. Code builds successfully
2. Architecture review passes
3. Dark/light mode switching works
4. Previews function correctly

## Estimated Effort

6 independent tasks, estimated 1-2 hours to complete.
