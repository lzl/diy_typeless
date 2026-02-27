# Task 004: Swift Entity - VoiceCommandResult

## Goal
Create the `VoiceCommandResult` entity and `CommandAction` enum.

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/Entities/VoiceCommandResult.swift`

### 2. Code
```swift
import Foundation

/// Entity representing the result of processing a voice command.
struct VoiceCommandResult: Sendable {
    let processedText: String
    let action: CommandAction
}

/// Enum representing possible actions to take with the processed text.
enum CommandAction: Sendable {
    case replaceSelection
    case insertAtCursor
    case copyToClipboard
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
feat(domain): add VoiceCommandResult entity

- Add VoiceCommandResult struct for LLM processing output
- Add CommandAction enum for output disposition
- Mark both as Sendable

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
