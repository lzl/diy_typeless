# Task 008: Swift UseCase - ProcessVoiceCommandUseCase

## Goal
Create the `ProcessVoiceCommandUseCase` following Single Responsibility Principle.

## Reference BDD Scenario
- Scenario: 选中文本语音指令处理并粘贴结果
- Scenario: LLM API 调用失败

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/UseCases/ProcessVoiceCommandUseCase.swift`

### 2. Implementation Requirements
- Single Responsibility: Only processes voice command
- Must NOT handle output delivery (paste/copy)
- Must be `Sendable`
- Inject `LLMRepository` via constructor

### 3. Code
```swift
import Foundation

/// Protocol for ProcessVoiceCommandUseCase.
protocol ProcessVoiceCommandUseCaseProtocol: Sendable {
    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult
}

/// Use case for processing voice commands with selected text.
/// Single Responsibility: Processes voice command and returns result.
/// Does not handle output delivery (paste/copy) - that is the caller's responsibility.
final class ProcessVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol {
    private let llmRepository: LLMRepository

    init(llmRepository: LLMRepository = GeminiLLMRepository()) {
        self.llmRepository = llmRepository
    }

    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult {
        // Build prompt combining command and selected text
        let prompt = buildPrompt(command: transcription, selectedText: selectedText)

        // Call LLM
        let response = try await llmRepository.generate(
            apiKey: geminiKey,
            prompt: prompt,
            temperature: 0.3
        )

        // Return result with recommended action
        return VoiceCommandResult(
            processedText: response,
            action: .replaceSelection
        )
    }

    private func buildPrompt(command: String, selectedText: String) -> String {
        """
        User has selected the following text:
        '''
        \(selectedText)
        '''

        User says: \(command)

        Please understand the user's intent and perform the appropriate operation on the selected text.
        Only return the processed text, no explanations, no quotes.
        """
    }
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop.sh --testing
```

### Unit Test
Create `app/DIYTypeless/DIYTypelessTests/Domain/UseCases/ProcessVoiceCommandUseCaseTests.swift`:
```swift
import Testing
@testable import DIYTypeless

struct ProcessVoiceCommandUseCaseTests {
    @Test
    func testExecuteProcessesVoiceCommand() async throws {
        let mockLLMRepository = MockLLMRepository()
        mockLLMRepository.mockResponse = "你好世界"

        let useCase = ProcessVoiceCommandUseCase(llmRepository: mockLLMRepository)
        let result = try await useCase.execute(
            transcription: "Translate to Chinese",
            selectedText: "Hello world",
            geminiKey: "test-key"
        )

        #expect(result.processedText == "你好世界")
        #expect(result.action == .replaceSelection)
    }
}

// Mock for testing
final class MockLLMRepository: LLMRepository {
    var mockResponse: String!

    func generate(apiKey: String, prompt: String, temperature: Double?) async throws -> String {
        mockResponse
    }
}
```

## Dependencies
- Task 004: VoiceCommandResult
- Task 006: LLMRepository

## Commit Message
```
feat(domain): add ProcessVoiceCommandUseCase

- Implement use case for processing voice commands
- Build prompt combining command and selected text
- Return VoiceCommandResult with recommended action
- Follow Single Responsibility Principle

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
