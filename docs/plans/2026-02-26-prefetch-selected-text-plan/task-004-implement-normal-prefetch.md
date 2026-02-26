# Task 004: Implement - Normal Prefetch Flow

## Description

Implement core prefetch mechanism in `RecordingState` with injected scheduler (Green phase).

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

1. **Add Properties** to `RecordingState`:
   ```swift
   private var preselectedContext: SelectedTextContext?
   private var prefetchTask: Task<Void, Never>?
   private let prefetchScheduler: PrefetchScheduler
   private let prefetchDelay: Duration
   ```

2. **Update Initializer**:
   ```swift
   init(
       // ... existing ...
       prefetchScheduler: PrefetchScheduler = RealPrefetchScheduler(),
       prefetchDelay: Duration = .milliseconds(300)
   ) {
       // ...
       self.prefetchScheduler = prefetchScheduler
       self.prefetchDelay = prefetchDelay
   }
   ```

3. **Modify `handleKeyDown()`**:
   ```swift
   prefetchTask = prefetchScheduler.schedule(delay: prefetchDelay) { [weak self] in
       guard let self else { return }
       let context = await self.getSelectedTextUseCase.execute()
       guard !Task.isCancelled else { return }
       self.preselectedContext = context
   }
   ```

4. **Add Helper**:
   ```swift
   private func cleanupPrefetch() {
       if let task = prefetchTask {
           prefetchScheduler.cancel(task)
       }
       prefetchTask = nil
       preselectedContext = nil
   }
   ```

## Verification

Run test from Task 003 - should pass.

## Location

File: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

## depends-on

- Task 003

## Estimated Effort

30 minutes
