# Task 008: Test Generation Cancellation (Red)

## BDD Scenario

```gherkin
Scenario: Generation cancellation during parallel execution
  Given the user released Fn key and parallel operations started
  When the user presses Fn again before operations complete
  Then currentGeneration should be incremented
  And the results of the ongoing operations should be ignored
  And a new recording should start
```

## Goal

Write a failing test that verifies generation-based cancellation works correctly with parallel execution.

## What to Do

1. **Write testGenerationCancellation_IgnoresStaleResults**:
   - Given: Recording state with mocks configured with slow delays (e.g., 500ms)
   - When: Call `handleKeyUp()` and immediately trigger a new generation (simulate Fn press) before completion
   - Then: Verify the first generation's results are ignored
   - And: Verify a new recording starts
   - And: Verify the stale results don't update the UI

2. **Write testMultipleGenerations_OnlyLatestProcesses**:
   - Given: Multiple rapid Fn key up/down cycles
   - When: Several generations are created in quick succession
   - Then: Only the latest generation's results are processed

## Files to Create/Modify

- `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift` (add tests to existing file)

## Verification

Run the new tests and confirm they **fail** or reveal incorrect cancellation behavior:

```bash
cd app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testGenerationCancellation_IgnoresStaleResults
```

## Acceptance Criteria

1. Tests compile
2. Tests demonstrate current cancellation behavior
3. Tests fail if cancellation doesn't work correctly with parallel execution

## Dependencies

- Task 001: Mock infrastructure (needs configurable delays)
