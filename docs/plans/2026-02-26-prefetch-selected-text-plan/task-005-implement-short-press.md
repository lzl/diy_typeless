# Task 006: Implement - Short Press Handling

## Description

Implement short press cancellation logic in `handleKeyUp` (Green phase).

## BDD Scenario

```gherkin
Scenario: Short press cancels prefetch
  Given the user has text selected in the active application
  And the user presses the Fn key
  When the user releases the Fn key within 300ms
  Then the prefetch task is cancelled
  And the app uses an empty text context
  And enters transcription mode (not voice command mode)

Scenario: Release during prefetch in-progress
  Given the user has text selected in the active application
  And the user presses and holds the Fn key
  When 300ms elapses and prefetch starts
  But the user releases Fn before prefetch completes (e.g., at 400ms)
  Then the prefetch task is cancelled
  And the app uses an empty text context
  And enters transcription mode
```

## Implementation Requirements

1. **Update `handleKeyUp()`**:
   ```swift
   func handleKeyUp() async {
       guard isRecording else { return }

       // Cancel prefetch task
       prefetchTask?.cancel()
       prefetchTask = nil

       // ... existing setup ...

       // Use prefetched context or empty
       let context = preselectedContext ?? .empty
       preselectedContext = nil

       // Determine mode based on context
       if shouldUseVoiceCommandMode(context) {
           // ... voice command mode ...
       } else {
           // ... transcription mode ...
       }
   }
   ```

2. **Update `shouldUseVoiceCommandMode`** signature:
   ```swift
   private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool
   ```

## Verification

Run tests from Task 004 and 005 - should pass.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 004

## Estimated Effort

20 minutes
