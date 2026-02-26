# Task 003: Implement - Normal Prefetch Flow

## Description

Implement the core prefetch mechanism in `RecordingState` (Green phase).

## BDD Scenario

```gherkin
Scenario: Normal prefetch flow with selected text
  Given the user has text selected in the active application
  And the user presses and holds the Fn key
  When 300ms elapses while still holding Fn
  Then the app starts prefetching the selected text in background
  When the user releases the Fn key
  Then the app uses the prefetched text context immediately
  And enters voice command mode because hasSelection is true
```

## Implementation Requirements

1. **Add State Properties** to `RecordingState`:
   ```swift
   private var preselectedContext: SelectedTextContext?
   private var prefetchTask: Task<Void, Never>?
   private static let prefetchDelay: Duration = .milliseconds(300)
   ```

2. **Modify `handleKeyDown()`**:
   - After starting recording, schedule prefetch task:
   ```swift
   prefetchTask = Task { [weak self] in
       try? await Task.sleep(for: Self.prefetchDelay)
       guard let self, !Task.isCancelled else { return }

       let context = await getSelectedTextUseCase.execute()
       guard !Task.isCancelled else { return }

       self.preselectedContext = context
   }
   ```

3. **Modify `handleKeyUp()`**:
   - Cancel prefetch task
   - Use `preselectedContext ?? .empty` for flow determination
   - Clear `preselectedContext` after use

4. **Update `shouldUseVoiceCommandMode()`**:
   - Accept `SelectedTextContext` parameter instead of fetching

## Verification

Run test from Task 002 - should pass now.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 002

## Estimated Effort

30 minutes
