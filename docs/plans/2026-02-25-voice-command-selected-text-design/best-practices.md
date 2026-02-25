# Best Practices - 语音指令处理选中文本

## 1. macOS Accessibility API 最佳实践

### 1.1 选中文本获取策略

**推荐的多层回退策略**：

```swift
func getSelectedText(from element: AXUIElement) -> String? {
    // 第一层：直接读取 selectedText 属性
    if let text = readSelectedTextAttribute(from: element) {
        return text
    }

    // 第二层：读取 value + selected range
    if let text = readValueWithSelectedRange(from: element) {
        return text
    }

    // 第三层：读取整个 value（无选中时返回 nil）
    return nil
}

private func readSelectedTextAttribute(from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,
        &value
    )

    guard result == .success,
          let text = value as? String,
          !text.isEmpty else {
        return nil
    }

    return text
}

private func readValueWithSelectedRange(from element: AXUIElement) -> String? {
    // 读取完整文本
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXValueAttribute as CFString,
        &valueRef
    ) == .success,
          let fullText = valueRef as? String else {
        return nil
    }

    // 读取选中范围
    var rangeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXSelectedTextRangeAttribute as CFString,
        &rangeRef
    ) == .success else {
        return nil
    }

    // 转换 CFRange 到 NSRange
    var range = CFRange(location: 0, length: 0)
    AXValueGetValue(rangeRef as! AXValue, kAXValueCFRangeType, &range)

    let nsRange = NSRange(location: range.location, length: range.length)

    // 提取子串
    guard let swiftRange = Range(nsRange, in: fullText) else {
        return nil
    }

    return String(fullText[swiftRange])
}
```

### 1.2 应用兼容性处理

不同应用对 Accessibility API 的支持程度不同：

| 应用 | AXSelectedTextAttribute | AXValueAttribute | 推荐策略 |
|------|--------------------------|------------------|----------|
| Notes | ✅ 支持 | ✅ 支持 | 直接使用 selectedText |
| TextEdit | ✅ 支持 | ✅ 支持 | 直接使用 selectedText |
| VS Code | ⚠️ 部分 | ✅ 支持 | 使用 value + range |
| Chrome (地址栏) | ❌ 不支持 | ✅ 支持 | 仅使用 value |
| Safari | ✅ 支持 | ✅ 支持 | 直接使用 selectedText |
| Terminal | ❌ 不支持 | ❌ 不支持 | 不支持选中文本获取 |

**应用特定适配代码**：

```swift
enum AppCompatibility {
    case full       // 完整支持
    case partial    // 需要备选策略
    case none       // 完全不支持

    static func forApp(_ name: String) -> AppCompatibility {
        switch name.lowercased() {
        case "notes", "textedit", "safari":
            return .full
        case "code", "visual studio code", "chrome":
            return .partial
        case "terminal", "iterm2":
            return .none
        default:
            return .partial
        }
    }
}
```

### 1.3 性能优化

**AX API 调用在主线程执行，但需要控制频率**：

```swift
// ❌ 错误：在录音期间频繁轮询
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    let text = getSelectedText()  // 阻塞主线程
}

// ✅ 正确：只在 Fn 释放时获取一次
func handleKeyUp() {
    // 单次获取，不轮询
    let context = accessibilityRepo.getSelectedText()
    // ...
}
```

### 1.4 安全性检查

**密码字段检测**：

```swift
func checkIfSecureTextField(_ element: AXUIElement) -> Bool {
    // 方法1：检查 role
    var role: CFTypeRef?
    if AXUIElementCopyAttributeValue(
        element,
        kAXRoleAttribute as CFString,
        &role
    ) == .success {
        if let roleString = role as? String,
           roleString == (kAXSecureTextFieldRole as String) {
            return true
        }
    }

    // 方法2：检查 subrole
    var subrole: CFTypeRef?
    if AXUIElementCopyAttributeValue(
        element,
        kAXSubroleAttribute as CFString,
        &subrole
    ) == .success {
        if let subroleString = subrole as? String,
           subroleString.lowercased().contains("secure") {
            return true
        }
    }

    // 方法3：检查 AXSecureTextField marker（某些应用使用）
    var isSecure: CFTypeRef?
    if AXUIElementCopyAttributeValue(
        element,
        "AXSecureTextField" as CFString,
        &isSecure
    ) == .success {
        if let secure = isSecure as? Bool {
            return secure
        }
    }

    return false
}
```

---

## 2. LLM Prompt Engineering 最佳实践

### 2.1 Prompt 结构

**推荐的分层 Prompt 结构**：

```
[系统指令 - System Instruction]
你是专业的文本处理助手，理解用户意图并精确执行。

[任务描述 - Task Description]
用户选中了文本并给出了语音指令，请根据指令处理选中文本。

[输入格式 - Input Format]
<选中文本>
{{selected_text}}
</选中文本>

<用户指令>
{{voice_instruction}}
</用户指令>

[处理规则 - Processing Rules]
1. 保持原文语言，除非用户明确要求翻译
2. 只返回处理后的文本，不要解释
3. 不要添加 Markdown 格式标记
4. 保持原文的格式（段落、换行）

[输出要求 - Output Requirements]
- 直接输出结果文本
- 不包含引号包裹
- 不添加额外说明
```

### 2.2 Temperature 设置

| 场景 | Temperature | 说明 |
|------|-------------|------|
| 翻译 | 0.1-0.2 | 确定性高，减少创意发挥 |
| 润色 | 0.3-0.4 | 轻微优化，保留原意 |
| 改写 | 0.5-0.7 | 更多变化，但仍保持原意 |
| 创意写作 | 0.8-1.0 | 高自由度（不推荐用于此功能）|

**代码实现**：

```rust
// 根据指令类型动态设置 temperature
fn get_temperature_for_instruction(instruction: &str) -> f32 {
    let lower = instruction.to_lowercase();

    if lower.contains("translate") || lower.contains("翻译") {
        0.2
    } else if lower.contains("polish") || lower.contains("润色") {
        0.3
    } else if lower.contains("rewrite") || lower.contains("改写") {
        0.5
    } else {
        0.3  // 默认
    }
}
```

### 2.3 Token 限制管理

**输入截断策略**：

```rust
const MAX_INPUT_TOKENS: usize = 3000;  // 保留 1000 tokens 给输出
const AVG_CHARS_PER_TOKEN: usize = 4;

fn truncate_if_needed(text: &str, max_tokens: usize) -> String {
    let max_chars = max_tokens * AVG_CHARS_PER_TOKEN;

    if text.len() <= max_chars {
        return text.to_string();
    }

    // 在句子边界截断
    let truncated = &text[..max_chars];
    if let Some(last_period) = truncated.rfind('.') {
        format!("{}...(truncated)", &truncated[..last_period + 1])
    } else {
        format!("{}...(truncated)", truncated)
    }
}
```

### 2.4 输出验证

**后处理清理**：

```rust
fn clean_llm_output(output: &str) -> String {
    let mut cleaned = output.trim().to_string();

    // 移除可能的引号包裹
    if cleaned.starts_with('"') && cleaned.ends_with('"') {
        cleaned = cleaned[1..cleaned.len()-1].to_string();
    }

    if cleaned.starts_with('\'') && cleaned.ends_with('\'') {
        cleaned = cleaned[1..cleaned.len()-1].to_string();
    }

    // 移除 Markdown 代码块
    if cleaned.starts_with("```") {
        cleaned = cleaned
            .trim_start_matches("```")
            .trim_start_matches("text")
            .trim_start_matches("\n")
            .trim_end_matches("```")
            .trim()
            .to_string();
    }

    // 移除常见的解释前缀
    let prefixes_to_remove = [
        "Here is the processed text:",
        "Processed text:",
        "Result:",
        "Output:",
    ];

    for prefix in &prefixes_to_remove {
        if cleaned.starts_with(prefix) {
            cleaned = cleaned[prefix.len()..].trim().to_string();
        }
    }

    cleaned
}
```

---

## 3. API 调用优化

### 3.1 连接预热策略

**时机选择**：

```swift
// ✅ 在 Fn 按下时预热（用户准备说话）
func handleKeyDown() {
    startRecording()

    // 预热连接
    Task {
        await warmupConnections()
    }
}

// ❌ 不要在启动时预热（连接会超时）
// ❌ 不要每次调用都预热（浪费资源）
```

**预热实现**：

```rust
pub fn warmup_gemini_connection() -> Result<(), CoreError> {
    let client = get_http_client();
    let url = format!("{}", GEMINI_API_URL);  // 只检查 API 端点可达性

    // 发送轻量级请求（非流式 HEAD 请求）
    match client.head(&url).send() {
        Ok(_) => Ok(()),
        Err(_) => {
            // 即使失败也不报错，预热失败不是致命错误
            Ok(())
        }
    }
}
```

### 3.2 超时配置

**分层超时策略**：

```rust
// HTTP 客户端配置
let client = ClientBuilder::new()
    .connect_timeout(Duration::from_secs(5))      // 连接超时
    .timeout(Duration::from_secs(30))              // 总超时
    .pool_idle_timeout(Duration::from_secs(300))  // 连接池保持
    .build()?;

// 使用时的超时控制
pub fn process_text_with_llm(
    api_key: &str,
    prompt: &str,
    timeout_secs: u64,
) -> Result<String, CoreError> {
    let client = get_http_client();

    let response = client
        .post(&url)
        .header("x-goog-api-key", api_key)
        .json(&body)
        .timeout(Duration::from_secs(timeout_secs))  // 单次请求超时
        .send()?;

    // ...
}
```

### 3.3 重试策略

**指数退避实现**：

```rust
pub fn with_retry<T, F>(
    operation: F,
    max_retries: u32,
) -> Result<T, CoreError>
where
    F: Fn() -> Result<T, CoreError>,
{
    let mut last_error = None;

    for attempt in 0..max_retries {
        match operation() {
            Ok(result) => return Ok(result),
            Err(err) => {
                last_error = Some(err);

                // 只有特定错误才重试
                if !is_retryable_error(&err) {
                    return Err(err);
                }

                // 指数退避
                if attempt < max_retries - 1 {
                    let backoff = 2u64.pow(attempt);
                    sleep(Duration::from_secs(backoff));
                }
            }
        }
    }

    Err(last_error.unwrap())
}

fn is_retryable_error(error: &CoreError) -> bool {
    match error {
        CoreError::Http(_) => true,           // 网络错误
        CoreError::Api(msg) if msg.contains("429") => true,  // 限流
        CoreError::Api(msg) if msg.contains("5") => true,    // 服务端错误
        _ => false,
    }
}
```

---

## 4. UX 最佳实践

### 4.1 状态反馈

**ProcessingPhase 设计**：

```swift
enum ProcessingPhase {
    case recording(audioLevel: Float)
    case transcribing
    case processing(selectedText: String, instruction: String)  // 显示正在处理的信息
    case completing
    case completed(result: String)
    case failed(error: String)
}
```

**状态文字设计**：

| 阶段 | 状态文字 | 说明 |
|------|----------|------|
| 录音 | "Listening..." | 简单明确 |
| 转录 | "Transcribing..." | 用户知道发生了什么 |
| Voice Command | "Processing: \"指令内容\"" | 显示指令预览，确认系统理解正确 |
| 完成 | "Applied" / "Pasted" | 结果明确 |
| 失败 | 具体错误信息 | 如 "Service unavailable" |

### 4.2 错误处理 UX

**错误分类和用户提示**：

```swift
enum UserFacingError {
    case network(message: String)
    case permission(type: PermissionType)
    case serviceUnavailable(service: String)
    case invalidInput
    case unknown

    var displayText: String {
        switch self {
        case .network:
            return "Network error. Please check your connection."
        case .permission(.accessibility):
            return "Accessibility permission required. Click to open settings."
        case .serviceUnavailable(let service):
            return "\(service) is temporarily unavailable. Please try again."
        case .invalidInput:
            return "Could not process your request. Please try rephrasing."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var action: ErrorAction {
        switch self {
        case .permission(.accessibility):
            return .openSettings
        case .serviceUnavailable:
            return .retry
        default:
            return .dismiss
        }
    }
}
```

### 4.3 防止意外触发

**最小录音时长**：

```swift
private var keyDownTime: Date?
private let minimumRecordingDuration: TimeInterval = 0.3  // 300ms

func handleKeyDown() {
    keyDownTime = Date()
    startRecording()
}

func handleKeyUp() {
    guard let startTime = keyDownTime else { return }

    let duration = Date().timeIntervalSince(startTime)
    guard duration >= minimumRecordingDuration else {
        // 太短，视为误触
        cancelRecording()
        return
    }

    proceedWithProcessing()
}
```

**防止重复触发**：

```swift
@MainActor
@Observable
final class RecordingState {
    private var isProcessing = false

    func handleKeyDown() {
        guard !isProcessing else {
            // 正在处理中，忽略新的按键
            return
        }
        // ...
    }
}
```

---

## 5. 测试策略

### 5.1 单元测试模式

**UseCase 测试**：

```swift
@Test
func testVoiceCommandMode() async throws {
    // Given
    let mockSelectedTextRepo = MockSelectedTextRepository()
    mockSelectedTextRepo.mockContext = SelectedTextContext(
        text: "Hello world",
        isEditable: true,
        isSecure: false,
        applicationName: "TestApp"
    )

    let mockTextOutputRepo = MockTextOutputRepository()
    let useCase = SelectedTextCommandUseCase(
        selectedTextRepository: mockSelectedTextRepo,
        textOutputRepository: mockTextOutputRepo,
        // ... other mocks
    )

    // When
    let result = try await useCase.execute(
        groqKey: "test",
        geminiKey: "test",
        context: nil
    )

    // Then
    #expect(result.mode == .voiceCommand)
    #expect(mockTextOutputRepo.deliverCalled == true)
}

@Test
func testFallbackToTranscription() async throws {
    // Given: 无选中文本
    let mockSelectedTextRepo = MockSelectedTextRepository()
    mockSelectedTextRepo.mockContext = SelectedTextContext(
        text: nil,
        isEditable: false,
        isSecure: false,
        applicationName: "TestApp"
    )

    // ...

    // Then
    #expect(result.mode == .transcription)
}
```

### 5.2 集成测试模式

**Accessibility API 测试**：

```swift
@Test
func testAccessibilityPermission() async throws {
    let repo = AccessibilitySelectedTextRepository()

    // 测试无权限时的行为
    let context = await repo.getSelectedText()

    // 应该返回空上下文而不是崩溃
    #expect(context.text == nil)
}
```

### 5.3 Mock 实现

```swift
final class MockSelectedTextRepository: SelectedTextRepositoryProtocol {
    var mockContext: SelectedTextContext?

    func getSelectedText() async -> SelectedTextContext {
        return mockContext ?? SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: "Mock"
        )
    }
}

final class MockTextOutputRepository: TextOutputRepositoryProtocol {
    var deliverCalled = false
    var lastDeliveredText: String?

    func deliver(text: String) -> OutputResult {
        deliverCalled = true
        lastDeliveredText = text
        return .pasted
    }
}
```

---

## 6. 安全和隐私

### 6.1 数据脱敏检查

```swift
func containsSensitiveData(_ text: String) -> Bool {
    // 检查常见敏感模式
    let patterns = [
        #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#,  // 信用卡
        #"\b\d{3}-\d{2}-\d{4}\b"#,                          // SSN
        #"password\s*=\s*[^\s]+"i,                          // 密码字段
        #"api[_-]?key\s*=\s*[^\s]+"i,                       // API Key
    ]

    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }
    }

    return false
}
```

### 6.2 用户提示

**首次使用提示**：

```swift
func showFirstTimeNotice() {
    let alert = NSAlert()
    alert.messageText = "Voice Command Mode"
    alert.informativeText = """
    When you select text and speak, your selected text and voice instruction will be sent to Gemini AI for processing.

    Please avoid selecting sensitive information like passwords or credit card numbers.
    """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Got it")
    alert.addButton(withTitle: "Don't show again")

    let response = alert.runModal()
    if response == .alertSecondButtonReturn {
        UserDefaults.standard.set(true, forKey: "hideVoiceCommandNotice")
    }
}
```

---

## 7. 性能基准

### 7.1 目标指标

| 指标 | 目标值 | 测量方法 |
|------|--------|----------|
| Fn 释放到转录开始 | < 100ms | 日志时间戳 |
| Groq 转录延迟 | < 2s (平均 1s) | API 响应时间 |
| Gemini 处理延迟 | < 2s (平均 1s) | API 响应时间 |
| 总处理时间 | < 4s | 用户感知时间 |
| 内存占用 | < 50MB | Instruments |

### 7.2 性能测试

```swift
@Test
func testProcessingPerformance() async throws {
    let startTime = Date()

    let result = try await useCase.execute(
        groqKey: testKey,
        geminiKey: testKey,
        context: nil
    )

    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 5.0, "Processing should complete within 5 seconds")
}
```
