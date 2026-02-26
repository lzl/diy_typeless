# Task 005: Test - Short Press Cancellation

## Description

Write failing test for short press scenario where prefetch is cancelled (Red phase).

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
   - Mock `getSelectedTextUseCase` with delay
   - Call `handleKeyDown()`
   - Immediately call `handleKeyUp()` (< 300ms)
   - Verify `getSelectedTextUseCase.execute()` was NOT called (or result not used)
   - Verify transcription mode is entered (not voice command)

2. **Test**: `testReleaseDuringPrefetchUsesEmptyContext()`
   - Mock `getSelectedTextUseCase` with 200ms delay
   - Call `handleKeyDown()`
   - Wait 350ms (prefetch started but not complete)
   - Call `handleKeyUp()`
   - Verify empty context used, transcription mode entered

## Implementation Notes

```swift
func testShortPressCancelsPrefetch() async {
    // Arrange
    let mockUseCase = MockGetSelectedTextUseCase()
    mockUseCase.delay = .milliseconds(500) // Slow response
    mockUseCase.result = SelectedTextContext(text: "text", ...)

    let state = RecordingState(...)

    // Act
    await state.handleKeyDown()
    // Don't wait - release immediately
    await state.handleKeyUp()

    // Assert
    XCTAssertEqual(state.capsuleState, .transcribing) // Not processingCommand
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 003

## Estimated Effort

20 minutes
