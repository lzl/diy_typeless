# Task 009: Swift Repository - AccessibilitySelectedTextRepository

## Goal
Implement `SelectedTextRepository` using macOS Accessibility API.

## Reference BDD Scenario
- Scenario: 选中文本语音指令处理并粘贴结果
- Scenario: Accessibility API 获取选中文本失败
- Scenario: 选中密码字段文本
- Scenario: 目标应用不支持 AXSelectedText

## Implementation Steps

### 1. Create File
Create `app/DIYTypeless/DIYTypeless/Data/Repositories/AccessibilitySelectedTextRepository.swift`

### 2. Implementation Requirements
- Must execute Accessibility API calls on background thread
- Must implement multi-layer fallback strategy
- Must detect password fields (AXSecureTextField)
- Must check editability

### 3. Code Structure
See swiftui-clean-architecture-reviewer output for full implementation.

Key points:
- Use `DispatchQueue.global(qos: .userInitiated).async` for AX API calls
- Try `kAXSelectedTextAttribute` first
- Fall back to `kAXValueAttribute` + `kAXSelectedTextRangeAttribute`
- Detect secure text fields

## Verification

### Build Test
```bash
./scripts/dev-loop.sh --testing
```

### Unit Test
Create `app/DIYTypeless/DIYTypelessTests/Data/Repositories/AccessibilitySelectedTextRepositoryTests.swift`:
```swift
import Testing
@testable import DIYTypeless

struct AccessibilitySelectedTextRepositoryTests {
    @Test
    func testGetSelectedTextExecutesOnBackgroundThread() async {
        let repository = AccessibilitySelectedTextRepository()
        let context = await repository.getSelectedText()

        // Should not block main thread
        #expect(context.applicationName != "")
    }
}
```

## Dependencies
- Task 003: SelectedTextContext
- Task 005: SelectedTextRepository

## Commit Message
```
feat(data): add AccessibilitySelectedTextRepository

- Implement SelectedTextRepository using macOS Accessibility API
- Execute API calls on background thread
- Add multi-layer fallback strategy
- Detect password fields for security

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
