# Task 003: Implement Parallel Execution (Green)

## BDD Scenario

```gherkin
Scenario: Normal transcription mode with parallel execution
  Given the user is recording audio with Fn key held
  And no text is selected in the active application
  When the user releases the Fn key
  Then getSelectedTextUseCase and stopRecordingUseCase should run concurrently
  And the UI should transition to "Transcribing" after both complete
  And the total delay should be reduced compared to serial execution
```

## Goal

Modify `RecordingState.handleKeyUp()` to execute `getSelectedTextUseCase` and `stopRecordingUseCase` in parallel using Swift's `async let` pattern.

## What to Do

1. **Locate the method**: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`, method `handleKeyUp()`

2. **Replace serial calls with parallel**:
   - Change from sequential `await` calls to `async let` declarations
   - Use tuple destructuring with `try await` to wait for both results
   - Preserve existing generation check logic

3. **Preserve existing behavior**:
   - Generation increment and cancellation check remain unchanged
   - Error handling remains unchanged
   - UI state transition logic remains unchanged

## Files to Create/Modify

- `app/DIYTypeless/DIYTypeless/State/RecordingState.swift` (modify `handleKeyUp()` method)

## Verification

Run the test from Task 002 - it should now **pass**:

```bash
cd app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testParallelExecution_ReducedDelay
```

Expected: Test passes with total time ~100ms (within tolerance).

## Acceptance Criteria

1. Both use cases execute in parallel (verified by timing test)
2. All existing tests still pass
3. Code compiles without warnings
4. Generation cancellation check still works correctly

## Dependencies

- Task 002: Test must exist and fail before this implementation
