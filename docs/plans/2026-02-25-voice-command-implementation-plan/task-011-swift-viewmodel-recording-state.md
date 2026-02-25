# Task 011: Swift ViewModel - RecordingState Integration

## Goal
Modify `RecordingState` to integrate new UseCases and orchestrate Voice Command vs Transcription modes.

## Reference BDD Scenario
- All scenarios (orchestration logic)

## Implementation Steps

### 1. Modify File
Modify `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`

### 2. Changes Required

#### Add New Dependencies
```swift
private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol
```

#### Update Initializer
Add new parameters with defaults:
```swift
init(
    // ... existing parameters ...
    getSelectedTextUseCase: GetSelectedTextUseCaseProtocol = GetSelectedTextUseCase(),
    processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol = ProcessVoiceCommandUseCase()
) {
    // ... initialize new properties ...
}
```

#### Add Business Logic Method
```swift
private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool {
    context.hasSelection && !context.isSecure
}
```

#### Modify handleKeyUp
Add orchestration logic:
```swift
private func handleKeyUp() async {
    // ... existing setup ...

    // Step 1: Get selected text
    let selectedTextContext = await getSelectedTextUseCase.execute()

    // ... transcription ...

    // Step 3: Determine mode and execute
    if shouldUseVoiceCommandMode(selectedTextContext) {
        try await handleVoiceCommandMode(...)
    } else {
        try await handleTranscriptionMode(...)
    }
}
```

#### Add Mode Handlers
```swift
private func handleVoiceCommandMode(...) async throws { ... }
private func handleTranscriptionMode(...) async throws { ... }
```

## Verification

### Build Test
```bash
./scripts/dev-loop.sh --testing
```

### Unit Test
See bdd-specs.md for RecordingStateTests examples.

## Dependencies
- Task 007: GetSelectedTextUseCase
- Task 008: ProcessVoiceCommandUseCase
- Task 009: AccessibilitySelectedTextRepository
- Task 010: GeminiLLMRepository

## Commit Message
```
feat(presentation): integrate Voice Command feature into RecordingState

- Add GetSelectedTextUseCase and ProcessVoiceCommandUseCase dependencies
- Implement orchestration logic for Voice Command vs Transcription modes
- Add shouldUseVoiceCommandMode business logic
- Create handleVoiceCommandMode and handleTranscriptionMode handlers

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
