# Best Practices: Prefetch Selected Text

## Swift Concurrency Guidelines

### Task Cancellation Pattern

Always check cancellation at key points:

```swift
prefetchTask = Task { [weak self] in
    try? await Task.sleep(for: Self.prefetchDelay)

    // Check 1: After sleep, before starting work
    guard let self, !Task.isCancelled else { return }

    let context = await getSelectedTextUseCase.execute()

    // Check 2: After async work, before storing result
    guard !Task.isCancelled else { return }

    // Check 3: Self may be nil if deallocated
    self?.preselectedContext = context
}
```

### MainActor Safety

All state mutations must be on MainActor:

```swift
// CORRECT: Task captures @MainActor context
prefetchTask = Task { [weak self] in
    // ... async work ...
    await MainActor.run {
        self?.preselectedContext = context
    }
}

// ALSO CORRECT: RecordingState is @MainActor, so Task inherits it
@MainActor
final class RecordingState {
    // Task body runs on MainActor unless detached
    prefetchTask = Task { [weak self] in
        // This is still on MainActor!
    }
}
```

## Error Handling

### Silent Failures

Prefetch failures should not surface to user:

```swift
prefetchTask = Task { [weak self] in
    try? await Task.sleep(for: Self.prefetchDelay)
    guard let self, !Task.isCancelled else { return }

    // Use try? to ignore errors - prefetch is best-effort
    let context = await getSelectedTextUseCase.execute()

    guard !Task.isCancelled else { return }
    self.preselectedContext = context
}
```

### Empty Context Fallback

Always provide fallback when using preselectedContext:

```swift
let context = preselectedContext ?? .empty
```

## Testing Best Practices

### Time-Based Testing

Use `Task.sleep` with short durations in tests, or inject a scheduler:

```swift
// Production code
protocol PrefetchScheduler {
    func schedule(delay: Duration, operation: @escaping () async -> Void) -> Task<Void, Never>
    func cancel()
}

// Test uses immediate scheduler
final class ImmediatePrefetchScheduler: PrefetchScheduler {
    func schedule(delay: Duration, operation: @escaping () async -> Void) -> Task<Void, Never> {
        Task { await operation() }
    }
    func cancel() {}
}
```

### State Verification

Verify cleanup happens correctly:

```swift
func testKeyUpCleansUpPrefetch() async {
    // Arrange
    await state.handleKeyDown()
    try? await Task.sleep(for: .milliseconds(400)) // Wait for prefetch

    // Act
    await state.handleKeyUp()

    // Assert - verify internal state cleaned up (via behavior)
    // Next session should work correctly
    await state.handleKeyDown()
    // Should schedule new prefetch, not reuse old
}
```

## Code Quality

### Magic Numbers

Define delay as static constant:

```swift
private static let prefetchDelay: Duration = .milliseconds(300)
```

### Cleanup Consistency

Create dedicated cleanup method:

```swift
private func cleanupPrefetch() {
    prefetchTask?.cancel()
    prefetchTask = nil
    preselectedContext = nil
}
```

Use in all exit paths:
- `handleKeyUp()`
- `deactivate()`
- `handleCancel()`

## Performance Considerations

### Avoid Redundant Work

Don't prefetch if permissions not granted:

```swift
func handleKeyDown() async {
    guard status.allGranted else { ... }

    // Only schedule prefetch if we might use it
    schedulePrefetch()
}
```

### Task Priority

Use appropriate QoS for prefetch task:

```swift
// Default priority is fine - this is user-initiated work
prefetchTask = Task {
    // ...
}

// For explicit priority:
prefetchTask = Task(priority: .userInitiated) {
    // ...
}
```

## Common Pitfalls

### ❌ Don't Forget Weak Self

```swift
// WRONG: Creates retain cycle if RecordingState outlives task
prefetchTask = Task {
    try? await Task.sleep(for: Self.prefetchDelay)
    self.preselectedContext = ... // self strongly captured!
}

// CORRECT: Use weak self
prefetchTask = Task { [weak self] in
    // ...
}
```

### ❌ Don't Check Cancellation Too Late

```swift
// WRONG: May store stale result after cancellation
let context = await getSelectedTextUseCase.execute()
self.preselectedContext = context // Too late to check!

// CORRECT: Check before storing
let context = await getSelectedTextUseCase.execute()
guard !Task.isCancelled else { return }
self.preselectedContext = context
```

### ❌ Don't Access State from Background Thread

```swift
// WRONG: Assuming Task runs on background thread
prefetchTask = Task { [weak self] in
    // This might be on background thread!
    self?.preselectedContext = context // Thread-unsafe access
}

// CORRECT: RecordingState is @MainActor, so Task body is too
// Just use [weak self] normally
```

## Security Considerations

### Clipboard Access

Prefetch still triggers Clipboard method if Accessibility fails:

```swift
// In AccessibilitySelectedTextRepository
if !context.hasSelection {
    // This sends Cmd+C - may be unexpected during prefetch
    if let clipboardText = await getSelectedTextViaClipboardAsync() {
        // ...
    }
}
```

**Mitigation**: Document this behavior. It's acceptable because:
- Only happens if user holds Fn for 300ms (explicit intent)
- Same behavior as original implementation, just earlier
