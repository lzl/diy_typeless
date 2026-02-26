# Task 007: Implement Error Handling (Green)

## BDD Scenario

```gherkin
Scenario: Stop recording fails during parallel execution
  Given the user is recording audio with Fn key held
  When the user releases the Fn key
  And stopRecordingUseCase throws an error
  Then the error should be caught
  And the capsule should show error state
  And getSelectedTextUseCase result should be discarded
```

## Goal

Ensure error handling works correctly with parallel execution using `async let`.

## What to Do

1. **Understand async let error propagation**:
   - When using `async let`, errors are thrown when awaiting the tuple
   - If either task throws, the `try await` will throw
   - The error from the throwing task is propagated

2. **Verify error handling**:
   - Check that existing `do-catch` block correctly handles errors from parallel execution
   - Ensure error state is set correctly
   - Ensure capsule state shows error state

3. **Fix if necessary**:
   - If errors are not handled correctly, update the catch block
   - Ensure partial results are discarded when one task fails

## Files to Create/Modify

- `app/DIYTypeless/DIYTypeless/State/RecordingState.swift` (modify error handling if needed)

## Verification

Run tests from Task 006 - they should now **pass**:

```bash
cd app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testStopRecordingFailure_ErrorHandled
```

## Acceptance Criteria

1. Errors from either task are caught and handled
2. Error state is correctly set in the UI
3. Partial results are discarded
4. All previous tests still pass

## Dependencies

- Task 006: Test must exist
- Task 003: Parallel execution implementation
