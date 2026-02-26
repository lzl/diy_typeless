# Task 007: Test - Rapid Key Presses and Cleanup

## Description

Write failing tests for rapid key presses and state cleanup scenarios (Red phase).

## BDD Scenarios

```gherkin
Scenario: Rapid key presses
  Given the user presses Fn and holds for 100ms then releases
  And immediately presses Fn again and holds
  When the second press lasts more than 300ms
  Then a new prefetch task starts for the second press
  And the first cancelled task has no effect

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

## Test Requirements

1. **Test**: `testRapidKeyPresses()`
   - First press: handleKeyDown, wait 100ms, handleKeyUp
   - Second press (immediately): handleKeyDown, wait 400ms, handleKeyUp
   - Verify second prefetch works correctly

2. **Test**: `testDeactivateCancelsPrefetch()`
   - handleKeyDown, wait 200ms (prefetch scheduled)
   - deactivate()
   - Verify no crash, state cleaned

3. **Test**: `testHandleCancelCancelsPrefetch()`
   - handleKeyDown, wait 200ms
   - handleCancel()
   - Verify prefetch cancelled, recording stopped

## Implementation Notes

```swift
func testRapidKeyPresses() async {
    // First press - short
    await state.handleKeyDown()
    try? await Task.sleep(for: .milliseconds(100))
    await state.handleKeyUp()

    // Immediately second press - long
    await state.handleKeyDown()
    try? await Task.sleep(for: .milliseconds(400))
    await state.handleKeyUp()

    // Assert second prefetch was used
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 005

## Estimated Effort

25 minutes
