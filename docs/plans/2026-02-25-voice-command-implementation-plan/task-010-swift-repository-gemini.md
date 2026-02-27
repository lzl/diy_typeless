# Task 010: Swift Repository - GeminiLLMRepository

## Goal
Implement `LLMRepository` using Rust FFI.

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Data/Repositories/GeminiLLMRepository.swift`

### 2. Implementation Requirements
- Wrap synchronous FFI call in async continuation
- Execute on background thread
- Handle errors appropriately

### 3. Code
```swift
import Foundation

/// Repository implementation that calls Gemini API via Rust FFI.
/// Wraps synchronous FFI calls in async continuations on background thread.
final class GeminiLLMRepository: LLMRepository {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processTextWithLLM(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: Float(temperature ?? 0.3)
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop-build.sh --testing
```

### Prerequisites
- Task 002: Rust FFI export must be complete
- `processTextWithLLM` function must be available in generated FFI bindings

## Dependencies
- Task 002: Rust FFI export
- Task 006: LLMRepository protocol

## Commit Message
```
feat(data): add GeminiLLMRepository

- Implement LLMRepository using Rust FFI
- Wrap synchronous FFI calls in async continuations
- Execute on background thread to avoid blocking UI

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
