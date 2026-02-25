# Task 007: Swift UseCase - GetSelectedTextUseCase

## Goal
Create the `GetSelectedTextUseCase` following Single Responsibility Principle.

## Reference BDD Scenario
- Scenario: 选中文本语音指令处理并粘贴结果
- Scenario: Accessibility API 获取选中文本失败

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/UseCases/GetSelectedTextUseCase.swift`

### 2. Implementation Requirements
- Single Responsibility: Only retrieves selected text
- Must be `Sendable`
- Inject `SelectedTextRepository` via constructor

### 3. Code
```swift
import Foundation

/// Protocol for GetSelectedTextUseCase.
protocol GetSelectedTextUseCaseProtocol: Sendable {
    func execute() async -> SelectedTextContext
}

/// Use case for retrieving selected text from the active application.
/// Single Responsibility: Only retrieves selected text, nothing else.
final class GetSelectedTextUseCase: GetSelectedTextUseCaseProtocol {
    private let repository: SelectedTextRepository

    init(repository: SelectedTextRepository = AccessibilitySelectedTextRepository()) {
        self.repository = repository
    }

    func execute() async -> SelectedTextContext {
        await repository.getSelectedText()
    }
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop.sh --testing
```

### Unit Test
Create `app/DIYTypeless/DIYTypelessTests/Domain/UseCases/GetSelectedTextUseCaseTests.swift`:
```swift
import Testing
@testable import DIYTypeless

struct GetSelectedTextUseCaseTests {
    @Test
    func testExecuteReturnsSelectedText() async {
        let mockRepository = MockSelectedTextRepository()
        mockRepository.mockContext = SelectedTextContext(
            text: "Hello world",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )

        let useCase = GetSelectedTextUseCase(repository: mockRepository)
        let result = await useCase.execute()

        #expect(result.hasSelection == true)
        #expect(result.text == "Hello world")
    }

    @Test
    func testExecuteReturnsEmptyContext() async {
        let mockRepository = MockSelectedTextRepository()
        mockRepository.mockContext = SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: "TestApp"
        )

        let useCase = GetSelectedTextUseCase(repository: mockRepository)
        let result = await useCase.execute()

        #expect(result.hasSelection == false)
    }
}

// Mock for testing
final class MockSelectedTextRepository: SelectedTextRepository {
    var mockContext: SelectedTextContext!

    func getSelectedText() async -> SelectedTextContext {
        mockContext
    }
}
```

## Dependencies
- Task 003: SelectedTextContext
- Task 005: SelectedTextRepository

## Commit Message
```
feat(domain): add GetSelectedTextUseCase

- Implement use case for retrieving selected text
- Follow Single Responsibility Principle
- Add protocol for testability

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
