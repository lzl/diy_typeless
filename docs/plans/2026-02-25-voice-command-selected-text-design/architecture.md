# Architecture - 语音指令处理选中文本

## 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              User Interaction                                │
│  Select Text → Hold Fn → Speak → Release Fn                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Presentation Layer (Swift)                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │  RecordingState │  │ ProcessingCapsule│  │  Onboarding (Permissions)  │ │
│  │  @Observable    │  │  Status Display  │  │  Accessibility Permission  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Domain Layer (Swift)                              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  UseCases                                                           │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ SelectedTextCommandUse │  │  TranscriptionPipelineUseCase    │  │   │
│  │  │ Case (NEW)             │  │  (EXISTING - fallback)           │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Repository Protocols                                               │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ SelectedTextRepository │  │  TextOutputRepository            │  │   │
│  │  │ Protocol (NEW)         │  │  Protocol (EXISTING)             │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Entities                                                           │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ SelectedTextContext    │  │  VoiceCommandResult              │  │   │
│  │  │ (NEW)                  │  │  (NEW)                           │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Data Layer (Swift)                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Repository Implementations                                         │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ AccessibilitySelected  │  │  SystemTextOutputRepository      │  │   │
│  │  │ TextRepository (NEW)   │  │  (EXISTING)                      │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Infrastructure Layer                                 │
│                                                                             │
│  ┌────────────────────────────────┐  ┌─────────────────────────────────┐   │
│  │  FFI Bridge (UniFFI)           │  │  Rust Core                      │   │
│  │  - process_text_with_llm       │  │  ┌───────────────────────────┐  │   │
│  │  - transcribe_wav_bytes        │  │  │  llm_processor.rs (NEW)   │  │   │
│  │  - polish_text                 │  │  │  - process_with_llm()     │  │   │
│  │                                │  │  │  - retry logic            │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  │                                │  │  ┌───────────────────────────┐  │   │
│  │                                │  │  │  transcribe.rs            │  │   │
│  │                                │  │  │  - transcribe_wav_bytes() │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  │                                │  │  ┌───────────────────────────┐  │   │
│  │                                │  │  │  polish.rs                │  │   │
│  │                                │  │  │  - polish_text()          │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  └────────────────────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              External Services                               │
│  ┌──────────────────────────┐  ┌──────────────────────────────────────────┐ │
│  │  Groq API                │  │  Gemini API                              │ │
│  │  - Whisper Transcription │  │  - Text Processing                       │ │
│  │  - Audio → Text          │  │  - Instruction + Context → Result        │ │
│  └──────────────────────────┘  └──────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 组件详情

### 1. SelectedTextContext

**职责**：封装选中文本的上下文信息

```swift
struct SelectedTextContext: Sendable {
    let text: String?           // 选中的文本内容
    let isEditable: Bool        // 是否可编辑
    let isSecure: Bool          // 是否是密码字段
    let applicationName: String // 来源应用

    // 计算属性
    var hasSelection: Bool { ... }
    var isValidForProcessing: Bool { ... }
}
```

**状态矩阵**：

| text | isEditable | isSecure | hasSelection | isValidForProcessing | 处理方式 |
|------|------------|----------|--------------|---------------------|----------|
| nil | - | - | false | false | 回退转录 |
| "" | - | - | false | false | 回退转录 |
| "text" | true | false | true | true | Voice Command |
| "text" | false | false | true | true | 复制到剪贴板 |
| "text" | - | true | true | false | 错误提示 |

### 2. SelectedTextRepositoryProtocol

**职责**：抽象选中文本获取的数据源

```swift
protocol SelectedTextRepositoryProtocol: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
```

**设计决策**：
- 返回 `SelectedTextContext` 而非 `String?`，保留更多上下文信息
- 异步方法（`async`），因为 Accessibility API 可能有延迟
- `Sendable` 约束，支持 Swift Concurrency

### 3. AccessibilitySelectedTextRepository

**职责**：通过 macOS Accessibility API 获取选中文本

**实现策略**：
1. **主线程执行**：AX API 必须在主线程调用
2. **多层回退**：
   - 首先尝试 `kAXSelectedTextAttribute`（最直接）
   - 备选尝试 `kAXValueAttribute` + `kAXSelectedTextRangeAttribute`
3. **安全检查**：检测 `kAXSecureTextFieldRole` 防止处理密码
4. **权限处理**：无权限时返回空上下文，由上层提示用户

**关键代码路径**：

```
getSelectedText()
    ├── 获取焦点元素 (AXUIElementCreateSystemWide + kAXFocusedUIElementAttribute)
    ├── 检测密码字段 (kAXRoleAttribute == kAXSecureTextFieldRole)
    ├── 检测可编辑性 (AXEditable attribute + role check)
    └── 获取选中文本
            ├── 尝试 kAXSelectedTextAttribute
            └── 备选：kAXValueAttribute + range extraction
```

### 4. SelectedTextCommandUseCase

**职责**：协调整个语音指令处理流程

**流程图**：

```
┌─────────────────┐
│     Start       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Get Selected    │◄─────────────────────────────┐
│ Text            │                              │
└────────┬────────┘                              │
         │                                        │
         ▼                                        │
┌─────────────────┐     ┌──────────────┐        │
│ Stop Recording  │────►│ Get Audio    │        │
│                 │     │ Data         │        │
└────────┬────────┘     └──────────────┘        │
         │                                        │
         ▼                                        │
┌─────────────────┐     ┌──────────────┐        │
│ Transcribe with │────►│ Groq Whisper │        │
│ Groq            │     │              │        │
└────────┬────────┘     └──────────────┘        │
         │                                        │
         ▼                                        │
    ┌─────────┐                                   │
    │ Has Valid                                 │
    │ Selection?                                │
    └────┬────┘                                   │
   Yes /   \ No                                   │
      /     \                                     │
     ▼       ▼                                    │
┌────────┐ ┌──────────────┐                      │
│ Voice  │ │ Polish with  │                      │
│ Command│ │ Gemini       │                      │
│ Mode   │ │ (existing)   │                      │
└───┬────┘ └──────┬───────┘                      │
    │             │                               │
    ▼             ▼                               │
┌─────────────────┐                               │
│ Process with    │                               │
│ Gemini LLM      │                               │
│ (NEW function)  │                               │
└────────┬────────┘                               │
         │                                        │
         ▼                                        │
┌─────────────────┐                               │
│ Deliver Output  │───────────────────────────────┘
│ (Paste/Copy)    │         (Error: fallback to
└────────┬────────┘          transcription)
         │
         ▼
┌─────────────────┐
│      End        │
└─────────────────┘
```

### 5. LLM Processor (Rust)

**职责**：通用 LLM 文本处理

**函数签名**：

```rust
pub fn process_text_with_llm(
    api_key: &str,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError>
```

**设计考虑**：
1. **通用性**：不局限于"语音指令处理选中文本"场景，可用于其他 LLM 交互
2. **可配置**：temperature、system_instruction 可定制
3. **输出限制**：maxOutputTokens = 4096，防止过度生成
4. **重试策略**：指数退避，最多 3 次重试

## 数据流

### Voice Command Mode 数据流

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Audio   │────►│  Groq API    │────►│  Instruction │────►│  Gemini API  │
│  Input   │     │  Whisper     │     │  Text        │     │  Processing  │
└──────────┘     └──────────────┘     └──────┬───────┘     └──────┬───────┘
                                             │                    │
                                             │                    │
┌──────────┐     ┌──────────────┐           │                    │
│  Output  │◄────│  Paste/Cmd+V │◄──────────┘◄───────────────────┘
│  Result  │     │  (System)    │
└──────────┘     └──────────────┘
       ▲
       │
┌──────┴───────┐
│ Selected Text│
│ (from AX API)│
└──────────────┘
```

### 关键数据结构

**Prompt 构造**（Swift 层）：

```swift
let prompt = """
用户选中了以下文本：
'''<selected_text>'''

用户说：<voice_instruction>

请理解用户的意图，对选中的文本执行相应操作。
只返回处理后的文本，不要解释，不要加引号。
"""
```

**API 请求体**（Rust 层）：

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "<prompt>"}]
    }
  ],
  "generationConfig": {
    "temperature": 0.3,
    "maxOutputTokens": 4096
  }
}
```

## 依赖关系

### Swift 层依赖

```
SelectedTextCommandUseCase
    ├── SelectedTextRepositoryProtocol
    │       └── AccessibilitySelectedTextRepository (impl)
    ├── TextOutputRepositoryProtocol
    │       └── SystemTextOutputRepository (impl, existing)
    └── FFI Functions
            ├── stopRecording() -> WavData
            ├── transcribeWavBytes() -> String
            └── process_text_with_llm() -> String (NEW)
```

### Rust 层依赖

```
llm_processor.rs
    ├── config::GEMINI_API_URL
    ├── config::GEMINI_MODEL
    ├── error::CoreError
    └── http_client::get_http_client
```

## 线程模型

### Swift 并发

1. **MainActor**：
   - `RecordingState`：UI 状态更新
   - `AccessibilitySelectedTextRepository.getSelectedText()`：AX API 调用

2. **Global Dispatch Queue**（`qos: .userInitiated`）：
   - FFI 调用包装（避免阻塞 MainActor）
   - LLM API 调用

### Rust 并发

- 当前实现使用同步 HTTP 客户端（`reqwest::blocking`）
- 由 Swift 层的 `DispatchQueue.global` 包装为异步
- 未来可迁移到 `tokio` 实现真正的异步

## 错误传播

```
CoreError (Rust)
    ├── Network/Timeout ──► UserFacingError.network
    ├── API Error ────────► UserFacingError.serviceUnavailable
    ├── Empty Response ───► UserFacingError.emptyResponse
    └── Invalid Input ────► UserFacingError.invalidInput

Accessibility Error (Swift)
    ├── No Permission ────► UserFacingError.permissionRequired
    ├── Unsupported App ──► Fallback to transcription (silent)
    └── API Failure ──────► Fallback to transcription (silent)
```

## 扩展点

### 1. 添加专用指令模式

```swift
enum VoiceCommandType {
    case generic           // 当前实现
    case translate(String) // 翻译到指定语言
    case summarize         // 总结
    case format            // 格式化
}

// 在 UseCase 中添加意图识别
private func detectCommandType(_ instruction: String) -> VoiceCommandType {
    // 使用本地规则或轻量级 LLM 调用
}
```

### 2. 支持多模态（Gemini 2.0 Flash）

```rust
// 直接发送音频，跳过转录步骤
pub fn process_audio_with_context(
    api_key: &str,
    audio: &[u8],
    selected_text: &str,
) -> Result<String, CoreError> {
    // Gemini 2.0 Flash 支持音频输入
}
```

### 3. 本地意图识别

```swift
// 使用 Core ML 模型本地识别常见指令
final class LocalIntentClassifier {
    func classify(_ text: String) -> VoiceCommandType? {
        // 减少云端 LLM 调用
    }
}
```
