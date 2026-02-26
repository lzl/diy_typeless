# Task 004: Test Voice Command Mode (Red)

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

Write a failing test that verifies voice command mode works correctly with parallel execution when text is selected.

## What to Do

1. **Write testVoiceCommandMode_WithSelectedText**:
   - Given: Recording state with mock returning selected text "hello world"
   - When: Call `handleKeyUp()`
   - Then: Verify selected text "hello world" is captured
   - And: Verify audio data is captured
   - And: Verify both operations ran in parallel (timing check)
   - And: Verify voice command mode state is set correctly

2. **Write testVoiceCommandMode_EmptySelectedText**:
   - Given: Recording state with mock returning empty selected text
   - When: Call `handleKeyUp()`
   - Then: Verify normal transcription mode (not voice command mode)

## Files to Create/Modify

- `app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift` (add tests to existing file)

## Verification

Run the new tests and confirm they **fail** or reveal missing behavior:

```bash
cd /Users/lzl/conductor/workspaces/diy_typeless/monrovia/app/DIYTypeless
xcodebuild test -scheme DIYTypeless -destination 'platform=macOS' \
  -only-testing:DIYTypelessTests/RecordingStateTests/testVoiceCommandMode_WithSelectedText
```

## Acceptance Criteria

1. Tests compile
2. Tests fail with clear assertions about voice command mode behavior
3. Tests verify parallel execution timing

## Dependencies

- Task 001: Mock infrastructure
- Task 003: Parallel execution implementation (tests may partially pass but voice command logic may need adjustment)
