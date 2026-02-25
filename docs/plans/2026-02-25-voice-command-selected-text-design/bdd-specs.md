# BDD Specifications - 语音指令处理选中文本

## Feature: 语音指令处理选中文本

As a user
I want to use voice commands to process selected text
So that I can quickly polish, translate, or transform text without typing

---

## Background

```gherkin
Given the user has completed onboarding
And the user has granted Accessibility permissions
And the user has configured Groq and Gemini API keys
And the user is in an application with text editing capabilities
```

---

## Scenarios

### 正常流程

#### Scenario: 选中文本语音指令处理并粘贴结果

```gherkin
Given the user has selected text "Hello world" in the active application
And the focused element is an editable text field
When the user holds the Fn key and says "Translate to Chinese"
And the user releases the Fn key
Then the system should capture the voice command "Translate to Chinese"
And the system should retrieve the selected text "Hello world"
And the system should construct a prompt combining the command and selected text
And the system should send the prompt to Gemini API
And the system should receive the processed result "你好世界"
And the system should replace the selected text with "你好世界"
And the system should display "Voice command: \"Translate to Chinese\" applied" status in the capsule
And the system should hide the capsule after 1.2 seconds
```

#### Scenario: 选中文本润色并粘贴

```gherkin
Given the user has selected text "This is bad" in the active application
And the focused element is an editable text field
When the user holds the Fn key and says "Make it professional"
And the user releases the Fn key
Then the system should process the voice command with the selected text
And the system should receive polished text "This is unacceptable"
And the system should replace the selected text with the polished result
And the system should display "Voice command: \"Make it professional\" applied" status
```

#### Scenario: 选中文本总结

```gherkin
Given the user has selected a paragraph of text in the active application
When the user holds the Fn key and says "Summarize this"
And the user releases the Fn key
Then the system should send the selected text and instruction to Gemini
And the system should receive a summarized version
And the system should replace the selected paragraph with the summary
```

---

### 回退流程

#### Scenario: 无选中文本时回退到转录模式

```gherkin
Given the user has no text selected in the active application
When the user holds the Fn key and says "Hello world"
And the user releases the Fn key
Then the system should detect no selected text
And the system should fallback to transcription mode
And the system should transcribe the audio to "Hello world"
And the system should polish the transcribed text
And the system should paste the polished result into the focused text field
And the system should display "Pasted" status
```

#### Scenario: 选中空白字符时视为无选中文本

```gherkin
Given the user has selected whitespace "   " in the active application
When the user holds the Fn key and says "Test command"
And the user releases the Fn key
Then the system should detect the selection is effectively empty
And the system should fallback to transcription mode
And the system should process the voice command as transcription input
```

---

### 错误处理 - Accessibility API

#### Scenario: Accessibility API 获取选中文本失败

```gherkin
Given the user has selected text "Important text" in the active application
And the Accessibility API is temporarily unavailable
When the user holds the Fn key and says "Summarize this"
And the user releases the Fn key
Then the system should attempt to retrieve selected text
And the system should detect the Accessibility API failure
And the system should fallback to transcription mode
And the system should process the voice command as regular transcription
And the system should not display an error to the user
And the system should log the Accessibility error for debugging
```

#### Scenario: 无 Accessibility 权限时提示用户

```gherkin
Given the user has selected text "Test text" in the active application
And the user has revoked Accessibility permissions
When the user holds the Fn key and says "Process this"
And the user releases the Fn key
Then the system should detect missing Accessibility permissions
And the system should display error "Accessibility permissions required"
And the system should trigger the onboarding flow
And the system should not attempt to call LLM API
```

#### Scenario: 目标应用不支持 AXSelectedText

```gherkin
Given the user is using an application that does not expose AXSelectedText
When the user holds the Fn key and says "Translate"
And the user releases the Fn key
Then the system should attempt to retrieve selected text
And the system should receive nil from Accessibility API
And the system should fallback to transcription mode
And the system should process the voice command as regular transcription
```

---

### 错误处理 - LLM API

#### Scenario: LLM API 调用失败

```gherkin
Given the user has selected text "Process me" in the active application
And the Gemini API service is unavailable
When the user holds the Fn key and says "Make it better"
And the user releases the Fn key
Then the system should successfully retrieve the selected text
And the system should attempt to call Gemini API
And the system should detect the API failure
And the system should display error "LLM service unavailable"
And the system should keep the original text unchanged
And the system should hide the capsule after 2.0 seconds
```

#### Scenario: LLM API 返回空响应

```gherkin
Given the user has selected text "Test" in the active application
When the user holds the Fn key and says "Do something"
And the user releases the Fn key
Then the system should successfully retrieve the selected text
And the system should call Gemini API
And the system should receive an empty response from LLM
And the system should display error "Empty response from LLM"
And the system should keep the original text unchanged
```

#### Scenario: LLM API 请求超时

```gherkin
Given the user has selected text "Long text" in the active application
And the Gemini API response time exceeds 30 seconds
When the user holds the Fn key and says "Rewrite this"
And the user releases the Fn key
Then the system should successfully retrieve the selected text
And the system should call Gemini API with 30-second timeout
And the system should detect the timeout
And the system should display error "Request timeout"
And the system should cancel the API request
And the system should keep the original text unchanged
```

---

### 边界情况

#### Scenario: 选中文本为空字符串

```gherkin
Given the user has selected an empty string "" in the active application
When the user holds the Fn key and says "Process this"
And the user releases the Fn key
Then the system should detect the selection is empty
And the system should fallback to transcription mode
And the system should process the voice command as transcription input
And the system should not call LLM with empty context
```

#### Scenario: 语音指令为空

```gherkin
Given the user has selected text "Some text" in the active application
When the user holds the Fn key and says nothing
And the user releases the Fn key after 500ms
Then the system should detect empty audio input
And the system should display error "No speech detected"
And the system should not attempt to retrieve selected text
And the system should not call LLM API
And the system should hide the capsule after 2.0 seconds
```

#### Scenario: 选中文本超长

```gherkin
Given the user has selected text with length 10000 characters in the active application
When the user holds the Fn key and says "Summarize this"
And the user releases the Fn key
Then the system should detect the text exceeds token limit
And the system should truncate the text to fit LLM context window
And the system should include a note "(truncated)" in the prompt
And the system should process the truncated text
And the system should replace the selected text with the result
```

#### Scenario: 选中密码字段文本

```gherkin
Given the user has selected text in a password input field (AXSecureTextField)
When the user holds the Fn key and says "Process this"
And the user releases the Fn key
Then the system should detect the focused element is a secure text field
And the system should display error "Cannot process password fields"
And the system should not send secure text to LLM
And the system should hide the capsule after 2.0 seconds
```

#### Scenario: 目标元素不可编辑

```gherkin
Given the user has selected text "Read only" in a non-editable text area
When the user holds the Fn key and says "Change this"
And the user releases the Fn key
Then the system should successfully retrieve the selected text
And the system should process the voice command with LLM
And the system should receive the processed result
And the system should detect the target is not editable
And the system should copy the result to clipboard
And the system should display "Copied" status instead of "Pasted"
And the system should not attempt to paste into non-editable field
```

#### Scenario: 语音指令和选中文本组合超长

```gherkin
Given the user has selected text with length 5000 characters
When the user holds the Fn key and says a very long command with 1000 characters
And the user releases the Fn key
Then the system should calculate the total token count
And the system should prioritize the voice command
And the system should truncate the selected text to fit within limits
And the system should process the combination
And the system should replace the selected text with the result
```

#### Scenario: 用户快速按下释放 Fn 键

```gherkin
Given the user has selected text "Quick test" in the active application
When the user holds the Fn key and immediately releases it within 200ms
Then the system should not start recording
And the system should not change the capsule state
And the system should keep the original text unchanged
```

#### Scenario: 用户在处理过程中取消

```gherkin
Given the user has selected text "Processing" in the active application
And the user has initiated voice command processing
And the system is currently calling LLM API
When the user presses the Esc key
Then the system should cancel the LLM API request
And the system should discard any partial results
And the system should keep the original text unchanged
And the system should hide the capsule immediately
```

#### Scenario: 连续快速触发语音指令

```gherkin
Given the user has selected text "First" in the active application
And the user has already triggered one voice command processing
When the user attempts to hold Fn key again during processing
Then the system should ignore the second Fn key press
And the system should continue processing the first command
And the system should display "Processing..." status
And the system should prevent concurrent LLM API calls
```

---

## Testing Strategy

### 单元测试

1. **SelectedTextCommandUseCaseTests**
   - 测试有选中文本时走 Voice Command 路径
   - 测试无选中文本时回退到 Transcription 路径
   - 测试 LLM 失败时保留原始文本

2. **AccessibilitySelectedTextRepositoryTests**
   - 测试从 AXSelectedTextAttribute 读取
   - 测试密码字段检测
   - 测试可编辑性检查

3. **LLM Processor Tests (Rust)**
   - 测试 Prompt 构建
   - 测试 API 重试逻辑
   - 测试空响应处理

### 集成测试

1. **VoiceCommandFlowTests**
   - 完整的录音 → 选中文本获取 → LLM 处理 → 粘贴流程
   - 使用 Mock 的 Accessibility API 和 LLM API

### UI 测试

1. **CapsuleStatusTests**
   - 验证 Voice Command 模式下显示正确的状态文字
   - 验证错误状态显示和超时隐藏

---

## 实现优先级

### P0 - 核心功能
- [ ] 选中文本获取（AccessibilitySelectedTextRepository）
- [ ] 基础 Voice Command UseCase
- [ ] LLM 处理函数（Rust）
- [ ] 回退到转录模式

### P1 - 错误处理
- [ ] 密码字段保护
- [ ] Accessibility 权限检测
- [ ] LLM API 错误处理

### P2 - 优化
- [ ] 超长文本截断
- [ ] 连接预热优化
- [ ] 处理状态指示
