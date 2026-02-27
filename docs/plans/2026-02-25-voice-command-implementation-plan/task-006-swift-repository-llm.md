# Task 006: Swift Repository Protocol - LLMRepository

## Goal
Create the `LLMRepository` protocol.

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/Repositories/LLMRepository.swift`

### 2. Code
```swift
import Foundation

/// Repository protocol for LLM text generation.
/// Following project convention, protocol names do not have "Protocol" suffix.
protocol LLMRepository: Sendable {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop-build.sh --testing
```

## Dependencies
- None

## Commit Message
```
feat(domain): add LLMRepository protocol

- Define protocol for LLM text generation
- Support configurable temperature
- Mark as Sendable for concurrency safety

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
