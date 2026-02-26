# Task 006: Test Error Handling (Red)

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

Write a failing test that verifies error handling when `stopRecordingUseCase` throws an error during parallel execution.

## What to Do

1. **Write testStopRecordingFailure_ErrorHandled**:
   - Given: Recording state with `MockStopRecordingUseCase` configured to throw an error
   - When: Call `handleKeyUp()`
   - Then: Verify error is caught and stored in state
   - And: Verify capsule state shows error state
   - And: Verify `getSelectedTextUseCase` result is discarded (not used)

2. **Write testGetSelectedTextFailure_ErrorHandled** (if applicable):
   - Given: Recording state with `MockGetSelectedTextUseCase` configured to throw an error
   - When: Call `handleKeyUp()`
   - Then: Verify error handling behavior

## Files to Create/Modify

- `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift` (add tests to existing file)

## Verification

Run the new tests and confirm they **fail** or reveal incorrect error handling:

```bash
cd /Users/lzl/conductor/workspaces/diy_typeless/monrovia/app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testStopRecordingFailure_ErrorHandled
```

## Acceptance Criteria

1. Tests compile
2. Tests demonstrate current error handling behavior
3. Tests fail if error handling is incorrect or incomplete

## Dependencies

- Task 001: Mock infrastructure (needs ability to throw errors)
