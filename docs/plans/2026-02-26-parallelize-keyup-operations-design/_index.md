# Parallelize KeyUp Operations Design

## Context

### Problem Statement

When the user releases the Fn key, the capsule takes too long to transition from the waveform view to the "Transcribing" state. The delay is caused by serial execution of two independent operations:

1. `getSelectedTextUseCase.execute()` - Get selected text via Accessibility API or clipboard fallback (10-800ms)
2. `stopRecordingUseCase.execute()` - Stop recording and process audio (50-200ms)

The UI state change (`capsuleState = .transcribing`) only happens after both operations complete.

### Current Flow

```
handleKeyUp() called
    │
    ├── getSelectedTextUseCase.execute()  ← Wait 10-800ms
    │
    ├── stopRecordingUseCase.execute()    ← Wait 50-200ms
    │
    ├── capsuleState = .transcribing      ← UI change happens HERE
    │
    └── transcribeAudioUseCase.execute()  ← API call
```

**Total delay before UI change**: 60-1000ms (worst case)

### Root Cause Analysis

The two operations are independent but executed serially:

| Operation | Purpose | Dependencies |
|-----------|---------|--------------|
| `getSelectedTextUseCase` | Get selected text from active app | None |
| `stopRecordingUseCase` | Stop recording, process audio | None |

They access different resources:
- `getSelectedTextUseCase`: Accessibility API / System clipboard
- `stopRecordingUseCase`: Rust FFI / Audio buffer

No shared state, no race conditions.

## Requirements

### Functional Requirements

1. FR1: The capsule must transition to "Transcribing" state faster when Fn is released
2. FR2: Selected text must be correctly captured when user intends to use voice command mode
3. FR3: Audio must be correctly processed and transcribed

### Non-Functional Requirements

1. NFR1: Reduce UI transition delay from 60-1000ms to ~max(10-800ms, 50-200ms)
2. NFR2: No regression in functionality
3. NFR3: Code must follow Clean Architecture principles

### Success Criteria

1. SC1: UI transition happens immediately after the longer of the two operations completes
2. SC2: All existing tests pass
3. SC3: Manual testing confirms improved perceived performance

## Rationale

### Why Parallelization?

- Both operations are I/O bound (Accessibility API / Audio processing)
- They are independent with no shared mutable state
- Swift's structured concurrency (`async let`) makes this safe and straightforward

### Why Not Other Optimizations?

1. **UI pre-change**: Would show "Transcribing" before audio is ready - confusing for users
2. **Application blacklist**: Requires user testing to validate effectiveness
3. **Early capture on Fn down**: Requires larger architectural change

## Detailed Design

### Change Location

**File**: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

**Method**: `handleKeyUp()` (lines 178-227)

### Current Implementation

```swift
private func handleKeyUp() async {
    guard isRecording else { return }

    guard !isProcessing else { return }
    isRecording = false
    isProcessing = true

    currentGeneration += 1
    let gen = currentGeneration

    do {
        // Step 1: Get selected text and stop recording (SERIAL)
        let selectedTextContext = await getSelectedTextUseCase.execute()
        let audioData = try await stopRecordingUseCase.execute()

        guard currentGeneration == gen else { return }

        // Step 2: Transcribe audio
        capsuleState = .transcribing(progress: 0)
        // ...
    }
}
```

### Proposed Implementation

```swift
private func handleKeyUp() async {
    guard isRecording else { return }

    guard !isProcessing else { return }
    isRecording = false
    isProcessing = true

    currentGeneration += 1
    let gen = currentGeneration

    do {
        // Step 1: Get selected text and stop recording (PARALLEL)
        async let selectedTextContext = getSelectedTextUseCase.execute()
        async let audioData = try await stopRecordingUseCase.execute()

        // Await both results
        let (context, audio) = try await (selectedTextContext, audioData)

        guard currentGeneration == gen else { return }

        // Step 2: Transcribe audio
        capsuleState = .transcribing(progress: 0)
        // ...
    }
}
```

### Key Changes

1. Use `async let` to start both operations concurrently
2. Use `try await` on tuple to wait for both results
3. No other logic changes

### Error Handling

- If `stopRecordingUseCase.execute()` throws an error, the whole operation fails
- If `getSelectedTextUseCase.execute()` returns empty context, it's handled by existing logic
- Error handling remains unchanged

## Design Documents

- [BDD Specifications](./bdd-specs.md) - Behavior scenarios and testing strategy
- [Architecture](./architecture.md) - System architecture and component details
- [Best Practices](./best-practices.md) - Security, performance, and code quality guidelines
