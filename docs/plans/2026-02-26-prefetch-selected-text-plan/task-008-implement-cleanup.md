# Task 008: Implement - State Cleanup

## Description

Implement cleanup in `deactivate()` and `handleCancel()` (Green phase).

## BDD Scenarios

```gherkin
Scenario: App deactivated during prefetch
  Given the user is holding Fn with prefetch in progress
  When the app is deactivated
  Then deactivate() cancels the prefetch task

Scenario: Handle cancel called during prefetch
  Given the user is holding Fn with prefetch in progress
  When handleCancel() is called
  Then the prefetch task is cancelled
```

## Implementation Requirements

1. **Update `deactivate()`**:
   ```swift
   func deactivate() {
       keyMonitoringRepository.stop()
       cleanupPrefetch()
       // ... existing cleanup
   }
   ```

2. **Update `handleCancel()`**:
   ```swift
   func handleCancel() {
       cleanupPrefetch()
       // ... existing switch cases
   }
   ```

## Verification

Run tests from Task 007 - should pass.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 007

## Estimated Effort

15 minutes
