# Architecture: Prefetch Selected Text

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        RecordingState                           │
│                     (@MainActor @Observable)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ preselectedContext│  │   prefetchTask   │  │ isRecording    │ │
│  │ SelectedTextContext?│  │ Task<Void, Never>?│  │ Bool           │ │
│  └─────────────────┘  └──────────────────┘  └────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  handleKeyDown()                                                │
│    ├── Start recording                                          │
│    └── Schedule prefetch task (300ms delay)                     │
│                                                                 │
│  handleKeyUp()                                                  │
│    ├── Cancel prefetch task                                     │
│    ├── Stop recording                                           │
│    ├── Use preselectedContext or .empty                         │
│    └── Clear preselectedContext                                 │
│                                                                 │
│  deactivate() / handleCancel()                                  │
│    └── Cancel prefetch task + cleanup                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              GetSelectedTextUseCase (existing)                  │
│                                                                 │
│  execute() ──→ AccessibilitySelectedTextRepository              │
│                  ├── performAccessibilityQueryAsync()           │
│                  └── getSelectedTextViaClipboardAsync()         │
└─────────────────────────────────────────────────────────────────┘
```

## State Machine

### Prefetch State Transitions

```
                    ┌─────────────┐
         ┌─────────│   IDLE      │◄─────────────────┐
         │         │(no prefetch)│                  │
         │         └──────┬──────┘                  │
         │                │ Fn Down                 │
         │                ▼                         │
         │         ┌─────────────┐                  │
         │         │  SCHEDULED  │                  │
         │         │(300ms delay)│                  │
         │         └──────┬──────┘                  │
         │                │                         │
         │      ┌─────────┴─────────┐               │
         │      │                   │               │
    Fn Up│ (<300ms)           (>=300ms)            │
   Cancel│      │                   │               │
         │      ▼                   ▼               │
         │  ┌─────────┐      ┌─────────────┐        │
         │  │ CANCEL  │      │ PREFETCHING │        │
         └─►│  (done) │      └──────┬──────┘        │
            └─────────┘             │               │
                              Complete/Error         │
                                    │               │
                                    ▼               │
                              ┌─────────────┐       │
                              │  COMPLETED  │───────┘
                              │(has result) │  Fn Up
                              └─────────────┘ (use & clear)
```

## Data Flow

### Sequence: Normal Prefetch Flow

```
User          RecordingState      PrefetchTask    GetSelectedTextUseCase
 │                  │                   │                    │
 │──Fn Down───────►│                   │                    │
 │                  │──Start Recording──►                    │
 │                  │                   │                    │
 │                  │──Schedule(300ms)──►                    │
 │                  │                   │                    │
 │                  │◄────sleeping──────│                    │
 │                  │                   │                    │
 │   (300ms passes) │                   │                    │
 │                  │◄────awake─────────│                    │
 │                  │                   │                    │
 │                  │                   │──execute()────────►│
 │                  │                   │◄────async work─────│
 │                  │                   │                    │
 │                  │◄──store result────│                    │
 │                  │                   │                    │
 │──Fn Up─────────►│                   │                    │
 │                  │──cancel()────────►│                    │
 │                  │                   │                    │
 │                  │──use result────────────────────────────┤
 │                  │──clear result────►                    │
 │                  │                   │                    │
```

## Modified Files

### RecordingState.swift

**New Properties:**
```swift
private var preselectedContext: SelectedTextContext?
private var prefetchTask: Task<Void, Never>?
private static let prefetchDelay: Duration = .milliseconds(300)
```

**Modified Methods:**
- `handleKeyDown()`: Add prefetch scheduling
- `handleKeyUp()`: Use preselectedContext, cancel task
- `deactivate()`: Cancel prefetch, clear state
- `handleCancel()`: Cancel prefetch, clear state

### SelectedTextContext.swift (extension)

**New Static Property:**
```swift
extension SelectedTextContext {
    static var empty: SelectedTextContext { ... }
}
```

## Concurrency Considerations

### Thread Safety

1. **MainActor Isolation**: All state (`preselectedContext`, `prefetchTask`) is on `@MainActor`
2. **Task Cancellation**: `Task.sleep` checks `Task.isCancelled` on resume
3. **Race Condition**: `handleKeyUp` cancels task before reading result - safe because:
   - Cancellation is cooperative
   - Task checks `isCancelled` before storing result
   - Even if result stored after cancel, it's on MainActor so ordered

### Memory Management

```swift
// Weak self prevents retain cycle in long-running prefetch
prefetchTask = Task { [weak self] in
    try? await Task.sleep(for: Self.prefetchDelay)
    guard let self, !Task.isCancelled else { return }
    // ...
}
```

## Backward Compatibility

### Public Interface

- `RecordingState` initializer signature unchanged
- No new public methods added
- Observable `capsuleState` behavior unchanged

### Test Compatibility

- Existing tests use mocked `getSelectedTextUseCase`
- Prefetch will call mock same as before, just earlier
- Tests need to account for async prefetch timing

## Performance Impact

### Positive

- Reduced perceived latency on Fn Up (no waiting for accessibility query)
- Voice command mode starts immediately

### Negative

- Slight battery usage for 300ms delay task (negligible)
- Wasted work if user always short presses (acceptable trade-off)

### Neutral

- Same number of accessibility API calls overall
