# BDD Specifications: Prefetch Selected Text

## Feature: Delayed Prefetch of Selected Text

As a user, I want the app to prefetch my text selection during voice input so that when I release the Fn key, the processing starts immediately without waiting for accessibility queries.

---

## Scenario: Normal prefetch flow with selected text

**Given** the user has text selected in the active application
**And** the user presses and holds the Fn key
**When** 300ms elapses while still holding Fn
**Then** the app starts prefetching the selected text in background
**When** the user releases the Fn key
**Then** the app uses the prefetched text context immediately
**And** enters voice command mode because hasSelection is true

---

## Scenario: Short press cancels prefetch

**Given** the user has text selected in the active application
**And** the user presses the Fn key
**When** the user releases the Fn key within 300ms
**Then** the prefetch task is cancelled
**And** the app uses an empty text context
**And** enters transcription mode (not voice command mode)

---

## Scenario: Release during prefetch in-progress

**Given** the user has text selected in the active application
**And** the user presses and holds the Fn key
**When** 300ms elapses and prefetch starts
**But** the user releases Fn before prefetch completes (e.g., at 400ms)
**Then** the prefetch task is cancelled
**And** the app uses an empty text context
**And** enters transcription mode

---

## Scenario: No text selected - long press

**Given** the user has no text selected
**And** the user presses and holds the Fn key for more than 300ms
**When** prefetch completes with hasSelection=false
**And** the user releases the Fn key
**Then** the app uses the prefetched empty context
**And** enters transcription mode

---

## Scenario: Selection changed during prefetch

**Given** the user has text "Hello" selected
**And** the user presses and holds the Fn key
**When** 300ms elapses and prefetch starts
**And** the user changes selection to "World" while still holding Fn
**And** the user releases the Fn key
**Then** the app uses the prefetched "Hello" context (not "World")
**And** processes the voice command on "Hello"

---

## Scenario: Rapid key presses

**Given** the user presses Fn and holds for 100ms then releases
**And** immediately presses Fn again and holds
**When** the second press lasts more than 300ms
**Then** a new prefetch task starts for the second press
**And** the first cancelled task has no effect

---

## Scenario: Cancellation during cleanup

**Given** the user presses and holds the Fn key for more than 300ms
**And** prefetch completes successfully
**When** the user releases the Fn key
**Then** the prefetch task is cancelled (idempotent)
**And** the preselectedContext is used and then cleared

---

## Edge Cases

### Scenario: App deactivated during prefetch

**Given** the user is holding Fn with prefetch in progress
**When** the app is deactivated (e.g., user switches apps)
**Then** deactivate() cancels the prefetch task
**And** cleans up preselectedContext

### Scenario: Handle cancel called during prefetch

**Given** the user is holding Fn with prefetch in progress
**When** handleCancel() is called (e.g., via UI button)
**Then** the prefetch task is cancelled
**And** preselectedContext is cleared
**And** recording stops

---

## Test Implementation Notes

### Unit Test Helpers

```swift
// Mock time control for testing delays
actor MockPrefetchScheduler {
    var pendingTask: Task<Void, Never>?

    func schedule(delay: Duration, operation: @escaping () async -> Void) {
        pendingTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
```

### Key Test Assertions

1. **Task Cancellation**: Verify `prefetchTask?.cancel()` is called on short press
2. **State Reset**: Verify `preselectedContext = nil` after key up processing
3. **Delay Timing**: Verify prefetch only starts after 300ms using `Task.sleep`
4. **Thread Safety**: Verify all state mutations happen on `@MainActor`
