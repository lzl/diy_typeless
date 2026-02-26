# Task 008: Implement - State Cleanup

## Description

Implement cleanup logic in `deactivate()` and `handleCancel()` (Green phase).

## BDD Scenarios

```gherkin
Scenario: App deactivated during prefetch
  Given the user is holding Fn with prefetch in progress
  When the app is deactivated (e.g., user switches apps)
  Then deactivate() cancels the prefetch task
  And cleans up preselectedContext

Scenario: Handle cancel called during prefetch
  Given the user is holding Fn with prefetch in progress
  When handleCancel() is called (e.g., via UI button)
  Then the prefetch task is cancelled
  And preselectedContext is cleared
  And recording stops
```

## Implementation Requirements

1. **Update `deactivate()`**:
   ```swift
   func deactivate() {
       keyMonitoringRepository.stop()

       // Cancel prefetch and cleanup
       prefetchTask?.cancel()
       prefetchTask = nil
       preselectedContext = nil

       // ... existing cleanup ...
   }
   ```

2. **Update `handleCancel()`**:
   ```swift
   func handleCancel() {
       // ... existing switch case ...

       // Cancel prefetch in all cases
       prefetchTask?.cancel()
       prefetchTask = nil
       preselectedContext = nil

       // ... rest of cleanup ...
   }
   ```

3. **Add private helper (optional)**:
   ```swift
   private func cleanupPrefetch() {
       prefetchTask?.cancel()
       prefetchTask = nil
       preselectedContext = nil
   }
   ```

## Verification

Run tests from Task 006 and 007 - should pass.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 006

## Estimated Effort

15 minutes
