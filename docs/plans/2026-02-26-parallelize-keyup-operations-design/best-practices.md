# Best Practices

## Swift Concurrency Best Practices

### Use `async let` for Independent Operations

When operations don't depend on each other's results, use `async let` to start them concurrently:

```swift
// GOOD: Parallel execution
async let result1 = operation1()
async let result2 = operation2()
let (r1, r2) = try await (result1, result2)

// BAD: Serial execution
let result1 = await operation1()
let result2 = await operation2()
```

### Don't Over-Parallelize

Only parallelize operations that are:
1. Independent (no shared mutable state)
2. I/O bound or CPU intensive
3. Have comparable execution times

If one operation is much faster than another, parallelization won't help much.

### Handle Errors Appropriately

```swift
// Both operations can throw
async let selectedTextContext = getSelectedTextUseCase.execute()  // Never throws
async let audioData = try await stopRecordingUseCase.execute()   // Can throw

// If stopRecordingUseCase throws, selectedTextUseCase still completes
// but its result is discarded
let (context, audio) = try await (selectedTextContext, audioData)
```

## Performance Considerations

### Measuring Improvement

To measure the improvement:

```swift
let start = Date()
// ... parallel operations ...
let elapsed = Date().timeIntervalSince(start)
print("Parallel execution took \(elapsed)s")
```

### Expected Improvement

| Scenario | Before (Serial) | After (Parallel) | Improvement |
|----------|-----------------|------------------|-------------|
| Native app (AX API) | 60-100ms | 50-100ms | ~10ms |
| Chrome (clipboard) | 300-1000ms | 200-800ms | ~100-200ms |

The improvement is most noticeable when:
1. Clipboard fallback is triggered (Chrome, Electron apps)
2. Audio processing takes longer than selected text retrieval

## Code Quality

### Follow Clean Architecture

- Changes are confined to `RecordingState` (Presentation layer)
- Use cases remain unchanged
- No changes to Domain or Data layers

### Maintain Testability

The parallel code is testable because:
1. Use cases are injected via constructor
2. Mock use cases can simulate delays
3. Test can verify timing improvement

### Keep It Simple

This is a minimal change:
- Only 3 lines of code changed
- No new abstractions
- No new dependencies

## Security Considerations

### No New Security Risks

- Both operations already run in the app's sandbox
- No additional permissions required
- Clipboard access is already granted

### Password Field Protection

The existing password field detection is preserved:

```swift
// In AccessibilitySelectedTextRepository
let isSecure = checkIfSecureTextField(axElement)
if isSecure {
    return SelectedTextContext(text: nil, isEditable: false, isSecure: true, ...)
}
```

## Testing Guidelines

### Unit Test Timing

When testing parallel execution, use mock delays:

```swift
final class MockGetSelectedTextUseCase: GetSelectedTextUseCaseProtocol {
    func execute() async -> SelectedTextContext {
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        return SelectedTextContext(text: nil, isEditable: false, isSecure: false, applicationName: "Test")
    }
}

final class MockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    func execute() async throws -> AudioData {
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        return AudioData(bytes: Data(), duration_seconds: 1.0)
    }
}

// Test: Serial would take 150ms, parallel should take ~100ms
```

### Integration Test Checklist

1. Test with Safari (AX API support)
2. Test with Chrome (clipboard fallback)
3. Test with Terminal (no support)
4. Test with text selected
5. Test without text selected
6. Test rapid Fn press/release (generation cancellation)

## Documentation

### Update CLAUDE.md if Needed

If this optimization proves effective, consider documenting the parallel execution pattern for future reference.

### Code Comments

Add inline comments to explain the parallelization:

```swift
// Start both operations in parallel to reduce UI transition delay
// - getSelectedTextUseCase: 10-800ms (AX API or clipboard fallback)
// - stopRecordingUseCase: 50-200ms (audio processing)
async let selectedTextContext = getSelectedTextUseCase.execute()
async let audioData = try await stopRecordingUseCase.execute()
```
