# Task 006: Implement - Short Press Handling

## Description

Implement short press cancellation in `handleKeyUp` (Green phase).

## BDD Scenario

```gherkin
Scenario: Short press cancels prefetch
  Given the user has text selected in the active application
  And the user presses the Fn key
  When the user releases the Fn key within 300ms
  Then the prefetch task is cancelled
  And the app uses an empty text context
  And enters transcription mode (not voice command mode)
```

## Implementation Requirements

1. **Update `handleKeyUp()`**:
   ```swift
   func handleKeyUp() async {
       guard isRecording else { return }
       cleanupPrefetch()
       // ... rest of implementation
       let context = preselectedContext ?? .empty
       preselectedContext = nil
       // ... use context for mode determination
   }
   ```

2. **Update `shouldUseVoiceCommandMode`**:
   ```swift
   private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool {
       context.hasSelection && !context.isSecure
   }
   ```

## Verification

Run test from Task 005 - should pass.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 005

## Estimated Effort

20 minutes
