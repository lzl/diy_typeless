# Task 005: Implement Voice Command Mode (Green)

## BDD Scenario

```gherkin
Scenario: Voice command mode with selected text
  Given the user is recording audio with Fn key held
  And text "hello world" is selected in the active application
  When the user releases the Fn key
  Then getSelectedTextUseCase should capture "hello world"
  And stopRecordingUseCase should capture audio data
  And both operations should run in parallel
  And voice command mode should be activated
```

## Goal

Ensure voice command mode logic works correctly with parallel execution.

## What to Do

1. **Review existing voice command logic**:
   - Check how `RecordingState` determines voice command mode vs normal transcription
   - Verify selected text handling after parallel execution completes

2. **Update if necessary**:
   - If voice command mode determination depends on selected text, ensure it works with the parallel result tuple
   - No logic changes should be needed if the code uses the results after both complete

## Files to Create/Modify

- `app/DIYTypeless/DIYTypeless/State/RecordingState.swift` (modify only if voice command logic needs adjustment)

## Verification

Run tests from Task 004 - they should now **pass**:

```bash
cd app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testVoiceCommandMode_WithSelectedText
```

## Acceptance Criteria

1. Voice command mode activates when selected text is present
2. Normal transcription mode activates when no selected text
3. All tests from previous tasks still pass

## Dependencies

- Task 004: Test must exist
- Task 003: Parallel execution implementation
