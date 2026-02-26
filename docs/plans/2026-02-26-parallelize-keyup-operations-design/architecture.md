# Architecture

## System Context

The optimization affects the **RecordingState** component in the Presentation layer, which coordinates multiple use cases during the key-up event.

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    RecordingState                            │   │
│  │                                                              │   │
│  │  handleKeyUp() ──────────────────────────────────────────┐   │   │
│  │       │                                                   │   │   │
│  │       │  async let                                        │   │   │
│  │       ├─────────────────────┬────────────────────────────┤   │   │
│  │       │                     │                            │   │   │
│  │       ▼                     ▼                            │   │   │
│  │  ┌─────────────────┐  ┌─────────────────┐                │   │   │
│  │  │ GetSelectedText │  │ StopRecording   │  (PARALLEL)    │   │   │
│  │  │    UseCase      │  │    UseCase      │                │   │   │
│  │  └────────┬────────┘  └────────┬────────┘                │   │   │
│  │           │                    │                         │   │   │
│  └───────────┼────────────────────┼─────────────────────────┘   │
│              │                    │                              │
└──────────────┼────────────────────┼──────────────────────────────┘
               │                    │
               ▼                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                           Domain Layer                               │
│                                                                      │
│  ┌─────────────────────────┐    ┌─────────────────────────────────┐ │
│  │ GetSelectedTextUseCase  │    │ StopRecordingUseCase            │ │
│  │ Protocol                │    │ Protocol                        │ │
│  └───────────┬─────────────┘    └───────────────┬─────────────────┘ │
│              │                                   │                   │
└──────────────┼───────────────────────────────────┼───────────────────┘
               │                                   │
               ▼                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                            Data Layer                                │
│                                                                      │
│  ┌─────────────────────────────┐  ┌───────────────────────────────┐ │
│  │ AccessibilitySelectedText   │  │ StopRecordingUseCaseImpl      │ │
│  │ Repository                  │  │                               │ │
│  │                             │  │  ┌─────────────────────────┐  │ │
│  │  ┌───────────────────────┐  │  │  │ DispatchQueue.global()  │  │ │
│  │  │ DispatchQueue.global()│  │  │  │     ↓                   │  │ │
│  │  │     ↓                 │  │  │  │ FFI: stop_recording()   │  │ │
│  │  │ AXUIElement API       │  │  │  │     ↓                   │  │ │
│  │  │     ↓                 │  │  │  │ Audio Processing        │  │ │
│  │  │ Clipboard Fallback    │  │  │  │ (resample, enhance,     │  │ │
│  │  └───────────────────────┘  │  │  │  FLAC encode)           │  │ │
│  │                             │  │  └─────────────────────────┘  │ │
│  └─────────────────────────────┘  └───────────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Before Optimization (Serial)

```
Fn Released
    │
    ▼
┌─────────────────────────┐
│ getSelectedTextUseCase  │  10-800ms
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ stopRecordingUseCase    │  50-200ms
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ capsuleState =          │  UI Update
│   .transcribing         │
└─────────────────────────┘

Total: 60-1000ms
```

### After Optimization (Parallel)

```
Fn Released
    │
    ▼
┌─────────────────────────────────────────────┐
│           async let (parallel)               │
│  ┌─────────────────┐  ┌─────────────────┐   │
│  │getSelectedText  │  │stopRecording    │   │
│  │UseCase          │  │UseCase          │   │
│  │ 10-800ms        │  │ 50-200ms        │   │
│  └────────┬────────┘  └────────┬────────┘   │
│           │                    │            │
│           └────────┬───────────┘            │
│                    ▼                        │
│         try await (both results)            │
└────────────────────┬────────────────────────┘
                     │
                     ▼
         ┌─────────────────────────┐
         │ capsuleState =          │  UI Update
         │   .transcribing         │
         └─────────────────────────┘

Total: max(10-800ms, 50-200ms) = 50-800ms
Worst case improvement: ~200ms
```

## Swift Concurrency Model

### Actor Isolation

- `RecordingState` is `@MainActor @Observable`
- Both use cases execute on background threads via `DispatchQueue.global()`
- Results are returned to MainActor via continuation

### Structured Concurrency

```swift
// Both tasks start immediately
async let selectedTextContext = getSelectedTextUseCase.execute()
async let audioData = try await stopRecordingUseCase.execute()

// Wait for both (structured concurrency ensures no task is orphaned)
let (context, audio) = try await (selectedTextContext, audioData)
```

### Error Propagation

- `async let` with `try await` propagates errors from either task
- If either task fails, the other still completes (but result is discarded)
- This is acceptable because `handleKeyUp` will exit on error anyway

## Thread Safety

### No Shared Mutable State

| Resource | Access Pattern | Thread Safety |
|----------|----------------|---------------|
| Audio buffer (Rust) | Mutex protected | Safe |
| Accessibility API | Thread-safe | Safe |
| Clipboard | Global resource | Safe (serialized by OS) |

### Generation Counter

The `currentGeneration` counter is used to cancel outdated operations:

```swift
currentGeneration += 1
let gen = currentGeneration

// ... parallel operations ...

guard currentGeneration == gen else { return }  // Cancel if outdated
```

This works correctly with parallel execution because:
1. The counter is incremented before parallel operations start
2. The check happens after both operations complete
3. If a new operation starts, the counter changes and old results are discarded

## Dependencies

- Swift 5.5+ (for structured concurrency)
- iOS 15+ / macOS 12+ (for async/await)

No new dependencies required.
