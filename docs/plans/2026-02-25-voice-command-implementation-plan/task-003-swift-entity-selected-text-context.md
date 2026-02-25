# Task 003: Swift Entity - SelectedTextContext

## Goal
Create the `SelectedTextContext` entity following Clean Architecture anemic entity pattern.

## Reference BDD Scenario
- Scenario: 选中文本语音指令处理并粘贴结果
- Scenario: 选中密码字段文本
- Scenario: 目标元素不可编辑

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Domain/Entities/SelectedTextContext.swift`

### 2. Implementation Requirements
- Must be `Sendable`
- Must contain only data (no business logic like `isValidForProcessing`)
- Pure data computation only (`hasSelection`)

### 3. Code
```swift
import Foundation

/// Entity representing the context of selected text in the active application.
/// This is an anemic entity containing only data with no business logic.
struct SelectedTextContext: Sendable {
    let text: String?
    let isEditable: Bool
    let isSecure: Bool
    let applicationName: String

    /// Pure data computation, no business logic
    var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }
}
```

## Verification

### Build Test
```bash
./scripts/dev-loop.sh --testing
```

### Unit Test
Create `app/DIYTypeless/DIYTypelessTests/Domain/Entities/SelectedTextContextTests.swift`:
```swift
import Testing
@testable import DIYTypeless

struct SelectedTextContextTests {
    @Test
    func testHasSelectionWithText() {
        let context = SelectedTextContext(
            text: "Hello",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )
        #expect(context.hasSelection == true)
    }

    @Test
    func testHasSelectionWithNilText() {
        let context = SelectedTextContext(
            text: nil,
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )
        #expect(context.hasSelection == false)
    }

    @Test
    func testHasSelectionWithEmptyText() {
        let context = SelectedTextContext(
            text: "",
            isEditable: true,
            isSecure: false,
            applicationName: "TestApp"
        )
        #expect(context.hasSelection == false)
    }
}
```

## Dependencies
- None

## Commit Message
```
feat(domain): add SelectedTextContext entity

- Create anemic entity for selected text context
- Mark as Sendable for Swift Concurrency
- Add hasSelection computed property (pure data only)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
