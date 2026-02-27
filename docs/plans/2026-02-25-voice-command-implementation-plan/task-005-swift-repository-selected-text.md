# Task 005: Swift Repository Protocol - SelectedTextRepository

## Goal
Create the `SelectedTextRepository` protocol following project naming conventions.

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/Repositories/SelectedTextRepository.swift`

### 2. Implementation Requirements
- Must be `Sendable`
- Protocol name must NOT have "Protocol" suffix (follow project convention)

### 3. Code
```swift
import Foundation

/// Repository protocol for retrieving selected text from the active application.
/// Following project convention, protocol names do not have "Protocol" suffix.
protocol SelectedTextRepository: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop-build.sh --testing
```

## Dependencies
- Task 003: SelectedTextContext

## Commit Message
```
feat(domain): add SelectedTextRepository protocol

- Define protocol for selected text retrieval
- Follow project naming convention (no Protocol suffix)
- Mark as Sendable for concurrency safety

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
