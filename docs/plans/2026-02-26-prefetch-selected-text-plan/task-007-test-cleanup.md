# Task 007: Test - Rapid Key Presses and Cleanup

## Description

Write failing tests for rapid key presses and cleanup scenarios (Red phase).

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
  When the app is deactivated
  Then deactivate() cancels the prefetch task
```

## Test Requirements

1. **Test**: `testRapidKeyPresses()`
2. **Test**: `testDeactivateCancelsPrefetch()`
3. **Test**: `testHandleCancelCancelsPrefetch()`

## Implementation Notes

```swift
@Test("Rapid key presses")
func testRapidKeyPresses() async {
    let mockScheduler = MockPrefetchScheduler()
    let state = RecordingStateTestFactory.makeRecordingState(
        prefetchScheduler: mockScheduler
    )

    await state.handleKeyDown()
    await state.handleKeyUp()

    await state.handleKeyDown()
    #expect(mockScheduler.scheduledOperations.count == 2)
}

@Test("Deactivate cancels prefetch")
func testDeactivateCancelsPrefetch() async {
    let mockScheduler = MockPrefetchScheduler()
    let state = RecordingStateTestFactory.makeRecordingState(
        prefetchScheduler: mockScheduler
    )

    await state.handleKeyDown()
    state.deactivate()

    #expect(mockScheduler.cancelledTasks.count >= 1)
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 006

## Estimated Effort

20 minutes
