# BDD Specifications

## Feature: Parallelize KeyUp Operations

**As a** user
**I want** the capsule to transition faster from waveform to "Transcribing" state
**So that** I get immediate visual feedback when I release the Fn key

---

## Scenario 1: Normal transcription mode with parallel execution

```gherkin
Scenario: Normal transcription mode with parallel execution
  Given the user is recording audio with Fn key held
  And no text is selected in the active application
  When the user releases the Fn key
  Then getSelectedTextUseCase and stopRecordingUseCase should run concurrently
  And the UI should transition to "Transcribing" after both complete
  And the total delay should be reduced compared to serial execution
```

---

## Scenario 2: Voice command mode with selected text

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

---

## Scenario 3: Stop recording fails during parallel execution

```gherkin
Scenario: Stop recording fails during parallel execution
  Given the user is recording audio with Fn key held
  When the user releases the Fn key
  And stopRecordingUseCase throws an error
  Then the error should be caught
  And the capsule should show error state
  And getSelectedTextUseCase result should be discarded
```

---

## Scenario 4: Generation cancellation during parallel execution

```gherkin
Scenario: Generation cancellation during parallel execution
  Given the user released Fn key and parallel operations started
  When the user presses Fn again before operations complete
  Then currentGeneration should be incremented
  And the results of the ongoing operations should be ignored
  And a new recording should start
```

---

## Test Strategy

### Unit Tests

1. **Test parallel execution timing**: Mock both use cases with known delays, verify total time is `max(delay1, delay2)` not `delay1 + delay2`

2. **Test error propagation**: Mock `stopRecordingUseCase` to throw error, verify error handling

3. **Test generation cancellation**: Verify that results are ignored when generation changes

### Integration Tests

1. **Test with real Accessibility API**: Verify selected text is correctly captured

2. **Test with real audio recording**: Verify audio is correctly processed

### Manual Tests

1. **Perceived performance test**: User releases Fn key and times the UI transition

2. **Browser compatibility test**: Test with Chrome (clipboard fallback) and Safari (AX API)

---

## Verification Checklist

- [ ] All existing tests pass
- [ ] New unit tests for parallel execution added
- [ ] Manual testing confirms improved performance
- [ ] No regression in voice command mode
- [ ] No regression in normal transcription mode
