# Task 002: Test Parallel Execution (Red)

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

Write a failing test that verifies `getSelectedTextUseCase.execute()` and `stopRecordingUseCase.execute()` run in parallel when `handleKeyUp()` is called.

## What to Do

1. **Create RecordingStateTests class**:
   - Set up `RecordingState` with mock use cases
   - Configure mocks with known delays (e.g., GetSelectedText: 100ms, StopRecording: 50ms)

2. **Write testParallelExecution_ReducedDelay**:
   - Given: Recording state with mocks configured (100ms and 50ms delays)
   - When: Call `handleKeyUp()`
   - Then: Measure total elapsed time
   - Assert: Total time is approximately 100ms (max), not 150ms (sum)
   - Assert: Both use cases were executed exactly once

3. **Write testParallelExecution_BothExecuted**:
   - Verify both use cases are called regardless of their individual completion times

## Files to Create/Modify

- `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift` (new)

## Verification

Run the test and confirm it **fails** because the current implementation executes serially:

```bash
cd /Users/lzl/conductor/workspaces/diy_typeless/monrovia/app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testParallelExecution_ReducedDelay
```

Expected failure: Total time will be ~150ms (sum) instead of ~100ms (max).

## Acceptance Criteria

1. Test file compiles
2. Test runs and **fails** with clear assertion about timing
3. Test failure message indicates serial execution (sum of delays)

## Dependencies

- Task 001: Mock infrastructure must be complete
