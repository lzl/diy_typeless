# Task 005: Test - Short Press Cancellation

## Description

Write failing test for short press cancellation (Red phase).

## BDD Scenario

```gherkin
Scenario: Short press cancels prefetch
  Given the user has text selected in the active application
  And the user presses the Fn key
  When the user releases the Fn key within 300ms
  Then the prefetch task is cancelled
  And the app uses an empty text context
  And enters transcription mode (not voice command mode)
```

## Test Requirements

1. **Test**: `testShortPressCancelsPrefetch()`
   - Mock scheduler and useCase
   - Call `handleKeyDown()` then immediately `handleKeyUp()`
   - Verify scheduler.cancel was called
   - Verify transcription mode entered

## Implementation Notes

```swift
@Test("Short press cancels prefetch")
func testShortPressCancelsPrefetch() async {
    let mockScheduler = MockPrefetchScheduler()
    let state = RecordingStateTestFactory.makeRecordingState(
        prefetchScheduler: mockScheduler
    )

    await state.handleKeyDown()
    await state.handleKeyUp()

    #expect(mockScheduler.cancelledTasks.count == 1)
    // Verify transcription mode
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 004

## Estimated Effort

15 minutes
