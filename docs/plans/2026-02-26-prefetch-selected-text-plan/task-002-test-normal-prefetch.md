# Task 002: Test - Normal Prefetch Flow

## Description

Write failing test for normal prefetch flow scenario (Red phase).

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
   - Call `handleKeyDown()`
   - Wait 300ms+
   - Verify `getSelectedTextUseCase.execute()` was called
   - Call `handleKeyUp()`
   - Verify transcription flow uses the prefetched context

2. **Test Infrastructure**:
   - Need ability to control/mock time delay in tests
   - Consider making `prefetchDelay` injectable for testing

## Implementation Notes

Create test that will fail until implementation is added:

```swift
func testNormalPrefetchFlow() async {
    // Arrange
    let mockUseCase = MockGetSelectedTextUseCase()
    mockUseCase.result = SelectedTextContext(
        text: "selected text",
        isEditable: true,
        isSecure: false,
        applicationName: "TestApp"
    )

    let state = RecordingState(
        // ... dependencies ...
        getSelectedTextUseCase: mockUseCase
    )

    // Act
    await state.handleKeyDown()
    try? await Task.sleep(for: .milliseconds(350)) // Wait for prefetch
    await state.handleKeyUp()

    // Assert
    XCTAssertTrue(mockUseCase.executeWasCalled)
    // Verify voice command mode was entered (based on prefetched context)
}
```

## Location

File: `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift`

## depends-on

- Task 001

## Estimated Effort

20 minutes
