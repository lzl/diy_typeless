# Task 003: Test - Normal Prefetch Flow

## Description

Write failing test for normal prefetch flow using injected scheduler (Red phase).

## BDD Scenario

```gherkin
Scenario: Normal prefetch flow with selected text
  Given the user has text selected in the active application
  And the user presses and holds the Fn key
  When 300ms elapses while still holding Fn
  Then the app starts prefetching the selected text in background
  When the user releases the Fn key
  Then the app uses the prefetched text context immediately
  And enters voice command mode because hasSelection is true
```

## Test Requirements

1. **Test**: `testNormalPrefetchFlow()`
   - Mock `getSelectedTextUseCase` to return context with `hasSelection: true`
   - Use `MockPrefetchScheduler` to control timing
   - Call `handleKeyDown()` - verify scheduler.schedule was called with 300ms
   - Execute scheduled operation immediately (no real wait)
   - Call `handleKeyUp()`
   - Verify voice command mode is entered

## Implementation Notes

```swift
@Test("Normal prefetch flow with selected text")
func testNormalPrefetchFlow() async {
    let mockScheduler = MockPrefetchScheduler()
    let mockUseCase = MockGetSelectedTextUseCase()
    mockUseCase.result = SelectedTextContext(
        text: "selected text",
        isEditable: true,
        isSecure: false,
        applicationName: "TestApp"
    )

    let state = RecordingStateTestFactory.makeRecordingState(
        getSelectedTextUseCase: mockUseCase,
        prefetchScheduler: mockScheduler,
        prefetchDelay: .milliseconds(300)
    )

    await state.handleKeyDown()
    #expect(mockScheduler.scheduledOperations.count == 1)
    #expect(mockScheduler.scheduledOperations[0].delay == .milliseconds(300))

    await mockScheduler.executeScheduled()
    #expect(mockUseCase.executeWasCalled)

    await state.handleKeyUp()
    // Verify voice command mode
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 002

## Estimated Effort

20 minutes
