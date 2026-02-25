# Architecture - 语音指令处理选中文本

**版本**: 2.0 (Reviewed)
**更新日期**: 2026-02-25

---

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
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RecordingState (ViewModel)                                         │   │
│  │  - @Observable @MainActor                                           │   │
│  │  - 编排 UseCase 调用顺序                                            │   │
│  │  - 决定执行 Voice Command 还是 Transcription 模式                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────┐  ┌─────────────────────────────┐                     │
│  │ ProcessingCapsule│  │  Onboarding (Permissions)  │                     │
│  │  Status Display  │  │  Accessibility Permission  │                     │
│  └─────────────────┘  └─────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Domain Layer (Swift)                              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  UseCases (Single Responsibility)                                   │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ GetSelectedTextUseCase │  │  ProcessVoiceCommandUseCase      │  │   │
│  │  │ (NEW)                  │  │  (NEW)                           │  │   │
│  │  │ - Get selected text    │  │  - Process voice command         │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ TranscriptionPipelineUseCase (EXISTING - fallback)            │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Repository Protocols                                               │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ SelectedTextRepository │  │  LLMRepository                   │  │   │
│  │  │ (NEW)                  │  │  (NEW)                           │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ TextOutputRepository   │  │  (existing protocols...)         │  │   │
│  │  │ (EXISTING)             │  │                                  │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Entities (Anemic - Data Only)                                      │   │
│  │  ┌────────────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │ SelectedTextContext    │  │  VoiceCommandResult              │  │   │
│  │  │ - text: String?        │  │  - processedText: String         │  │   │
│  │  │ - isEditable: Bool     │  │  - action: CommandAction         │  │   │
│  │  │ - isSecure: Bool       │  │                                  │  │   │
│  │  │ - hasSelection (calc)  │  │                                  │  │   │
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
│  │  │ AccessibilitySelected  │  │  GeminiLLMRepository             │  │   │
│  │  │ TextRepository (NEW)   │  │  (NEW)                           │  │   │
│  │  │ - AX API calls         │  │  - FFI wrapper                   │  │   │
│  │  │ - Background thread    │  │                                  │  │   │
│  │  └────────────────────────┘  └──────────────────────────────────┘  │   │
│  │  ┌────────────────────────┐                                          │   │
│  │  │ SystemTextOutputRepository (EXISTING)                            │   │
│  │  └────────────────────────┘                                          │   │
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
│  │  - start/stop_recording        │  │  │  - retry logic            │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  │                                │  │  ┌───────────────────────────┐  │   │
│  │                                │  │  │  transcribe.rs            │  │   │
│  │                                │  │  │  - transcribe_wav_bytes() │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  │                                │  │  ┌───────────────────────────┐  │   │
│  │                                │  │  │  polish.rs                │  │   │
│  │                                │  │  │  - polish_text()          │  │   │
│  │                                │  │  └───────────────────────────┘  │   │
│  │                                │  │  ┌───────────────────────────┐  │   │
│  │                                │  │  │  audio.rs                 │  │   │
│  │                                │  │  │  - start/stop recording   │  │   │
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

---

## 组件详情

### 1. SelectedTextContext (Entity)

**职责**：封装选中文本的上下文信息（纯数据，贫血实体）

```swift
struct SelectedTextContext: Sendable {
    let text: String?
    let isEditable: Bool
    let isSecure: Bool
    let applicationName: String

    // 纯数据计算，无业务逻辑
    var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }
}
```

**状态矩阵**：

| text | isEditable | isSecure | hasSelection | 处理方式 |
|------|------------|----------|--------------|----------|
| nil | - | - | false | 回退转录 |
| "" | - | - | false | 回退转录 |
| "text" | true | false | true | Voice Command → 粘贴 |
| "text" | false | false | true | Voice Command → 复制 |
| "text" | - | true | true | 错误提示（密码字段） |

**注意**：业务规则判断（如 `isValidForProcessing`）移到 ViewModel 或 UseCase，不在 Entity 中。

### 2. SelectedTextRepository (Protocol)

**职责**：抽象选中文本获取的数据源

```swift
protocol SelectedTextRepository: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
```

**命名规范**：遵循项目惯例，Repository 协议**不加 Protocol 后缀**（如 `ApiKeyRepository`）。

### 3. GetSelectedTextUseCase

**职责**：获取选中文本（单一职责）

```swift
protocol GetSelectedTextUseCaseProtocol: Sendable {
    func execute() async -> SelectedTextContext
}

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

**设计原则**：一个 UseCase 只做一件事——获取选中文本。

### 4. ProcessVoiceCommandUseCase

**职责**：处理语音指令（单一职责）

```swift
struct VoiceCommandResult: Sendable {
    let processedText: String
    let action: CommandAction
}

enum CommandAction: Sendable {
    case replaceSelection
    case insertAtCursor
    case copyToClipboard
}

protocol ProcessVoiceCommandUseCaseProtocol: Sendable {
    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult
}

final class ProcessVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol {
    private let llmRepository: LLMRepository

    init(llmRepository: LLMRepository = GeminiLLMRepository()) {
        self.llmRepository = llmRepository
    }

    func execute(...) async throws -> VoiceCommandResult {
        // 1. 构建 Prompt
        // 2. 调用 LLMRepository
        // 3. 返回结果
    }
}
```

**依赖关系**：只依赖 Repository，不依赖其他 UseCase。

### 5. AccessibilitySelectedTextRepository

**职责**：通过 macOS Accessibility API 获取选中文本

**实现策略**：
1. **后台线程执行**：在 `DispatchQueue.global(qos: .userInitiated)` 执行 AX API 调用
2. **多层回退**：
   - 首先尝试 `kAXSelectedTextAttribute`
   - 备选尝试 `kAXValueAttribute` + `kAXSelectedTextRangeAttribute`
3. **安全检查**：检测 `kAXSecureTextFieldRole` 防止处理密码

**关键代码路径**：

```
getSelectedText()
    └── DispatchQueue.global(qos: .userInitiated).async
            └── performAccessibilityQuery()
                    ├── 获取焦点元素
                    ├── 检测密码字段
                    ├── 检测可编辑性
                    └── 获取选中文本
                            ├── 尝试 kAXSelectedTextAttribute
                            └── 备选：value + range extraction
```

### 6. RecordingState (ViewModel) - 编排者

**职责**：编排 UseCase 调用顺序，决定执行路径

```swift
@MainActor
@Observable
final class RecordingState {
    private func handleKeyUp() async {
        // 1. 获取选中文本
        let selectedTextContext = await getSelectedTextUseCase.execute()

        // 2. 停止录音并转录
        let wavData = try await stopRecordingAsync()
        let transcription = try await transcribeAsync(...)

        // 3. 业务规则判断（在 ViewModel 中）
        if shouldUseVoiceCommandMode(selectedTextContext) {
            // Voice Command Mode
            let result = try await processVoiceCommandUseCase.execute(...)
            textOutputRepository.deliver(text: result.processedText)
        } else {
            // Transcription Mode
            let result = try await transcriptionUseCase.execute(...)
        }
    }

    private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool {
        context.hasSelection && !context.isSecure
    }
}
```

**设计原则**：ViewModel 是编排者（Orchestrator），负责决定调用哪些 UseCase 以及调用顺序。

---

## 数据流

### Voice Command Mode 数据流

```
┌──────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────────┐
│  User    │────►│  Fn Key Release  │────►│ GetSelected  │────►│  AX API      │
│  Action  │     │  (RecordingState)│     │ TextUseCase  │     │  (Background)│
└──────────┘     └──────────────────┘     └──────────────┘     └──────┬───────┘
                                                                      │
                                                                      ▼
┌──────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Output  │◄────│  Cmd+V Paste     │◄────│  Deliver     │◄────│  Gemini API  │
│  Result  │     │  (System)        │     │  Result      │     │  Processing  │
└──────────┘     └──────────────────┘     └──────────────┘     └──────┬───────┘
                                                                      │
                                                                      ▼
                                                               ┌──────────────┐
                                                               │  Build       │
                                                               │  Prompt      │
                                                               │  (Text +     │
                                                               │   Command)   │
                                                               └──────────────┘
```

### Transcription Mode 数据流（Fallback）

```
┌──────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────────┐
│  User    │────►│  Fn Key Release  │────►│ GetSelected  │────►│  AX API      │
│  Action  │     │  (RecordingState)│     │ TextUseCase  │     │  (No text)   │
└──────────┘     └──────────────────┘     └──────────────┘     └──────────────┘
                                                                      │
                                                                      ▼ (Fallback)
┌──────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Output  │◄────│  Cmd+V Paste     │◄────│  Deliver     │◄────│  Gemini      │
│  Result  │     │  (System)        │     │  Result      │     │  Polish      │
└──────────┘     └──────────────────┘     └──────────────┘     └──────┬───────┘
                                                                      │
                                                                      ▼
                                                               ┌──────────────┐
                                                               │  Groq        │
                                                               │  Transcribe  │
                                                               └──────────────┘
```

---

## 依赖关系

### Swift 层依赖

```
RecordingState
    ├── GetSelectedTextUseCaseProtocol
    │       └── GetSelectedTextUseCase (impl)
    │               └── SelectedTextRepository (protocol)
    │                       └── AccessibilitySelectedTextRepository (impl)
    ├── ProcessVoiceCommandUseCaseProtocol
    │       └── ProcessVoiceCommandUseCase (impl)
    │               └── LLMRepository (protocol)
    │                       └── GeminiLLMRepository (impl)
    ├── TranscriptionUseCaseProtocol (existing)
    │       └── TranscriptionPipelineUseCase (impl)
    └── TextOutputRepository (protocol, existing)
            └── SystemTextOutputRepository (impl, existing)
```

### Rust 层依赖

```
llm_processor.rs
    ├── config::GEMINI_API_URL
    ├── config::GEMINI_MODEL
    ├── error::CoreError
    └── http_client::get_http_client
```

---

## 线程模型

### Swift Concurrency

1. **MainActor**：
   - `RecordingState`：UI 状态更新
   - ViewModel 编排逻辑

2. **Global Dispatch Queue**（`qos: .userInitiated`）：
   - FFI 调用包装
   - Accessibility API 调用
   - LLM API 调用

### 执行流程

```
handleKeyUp() [MainActor]
    │
    ├──► getSelectedTextUseCase.execute() [MainActor]
    │         │
    │         └──► repository.getSelectedText() [MainActor]
    │                   │
    │                   └──► withCheckedContinuation [MainActor]
    │                             │
    │                             └──► DispatchQueue.global(qos: .userInitiated)
    │                                       └──► AX API calls (background)
    │
    ├──► stopRecordingAsync() [Background via FFI]
    │
    ├──► transcribeAsync() [Background via FFI]
    │
    └──► processVoiceCommandUseCase.execute() [MainActor]
              │
              └──► llmRepository.generate() [MainActor]
                        │
                        └──► withCheckedContinuation [MainActor]
                                  │
                                  └──► DispatchQueue.global(qos: .userInitiated)
                                            └──► FFI call (background)
```

---

## 错误传播

```
CoreError (Rust)
    ├── Network/Timeout ──► RecordingError.network
    ├── API Error ────────► RecordingError.serviceUnavailable
    ├── Empty Response ───► RecordingError.emptyResponse
    └── Invalid Input ────► RecordingError.invalidInput

Accessibility Error (Swift)
    ├── No Permission ────► RecordingError.permissionRequired
    ├── Unsupported App ──► Fallback to transcription (silent)
    └── API Failure ──────► Fallback to transcription (silent)

Password Field Detected
    └──► RecordingError.secureTextField
```

---

## 扩展点

### 1. 添加本地意图识别

```swift
// Domain/Services/IntentClassifier.swift
protocol IntentClassifier: Sendable {
    func classify(_ instruction: String) -> VoiceCommandType?
}

// 在 ProcessVoiceCommandUseCase 中使用
final class ProcessVoiceCommandUseCase {
    private let intentClassifier: IntentClassifier?

    func execute(...) async throws -> VoiceCommandResult {
        // 本地识别常见指令，减少 LLM 调用
        if let commandType = intentClassifier?.classify(transcription) {
            return handleCommandType(commandType, selectedText: selectedText)
        }

        // 回退到 LLM
        return try await callLLM(...)
    }
}
```

### 2. 支持多模态（Gemini 2.0 Flash）

```rust
// core/src/multimodal.rs
pub fn process_audio_with_context(
    api_key: &str,
    audio: &[u8],
    selected_text: &str,
) -> Result<String, CoreError> {
    // Gemini 2.0 Flash 支持音频 + 文本输入
    // 跳过 Groq 转录步骤
}
```

### 3. 添加命令历史缓存

```swift
// Data/Repositories/CommandHistoryRepository.swift
protocol CommandHistoryRepository: Sendable {
    func save(command: String, result: String)
    func findSimilar(to command: String) -> [CommandHistoryEntry]
}
```

---

## Review 修正说明

### 原设计问题

| 问题 | 原设计 | 修正后 |
|------|--------|--------|
| UseCase 臃肿 | `SelectedTextCommandUseCase` 做了 5 件事 | 拆分为 `GetSelectedTextUseCase` + `ProcessVoiceCommandUseCase` |
| Entity 含业务逻辑 | `SelectedTextContext.isValidForProcessing` | 移到 ViewModel 的 `shouldUseVoiceCommandMode` |
| Repository 命名 | `SelectedTextRepositoryProtocol` | `SelectedTextRepository`（无 Protocol 后缀） |
| AX API 线程 | `DispatchQueue.main.async` | `DispatchQueue.global(qos: .userInitiated).async` |
| UseCase 依赖 | `baseTranscriptionUseCase: TranscriptionUseCaseProtocol` | ViewModel 直接编排，UseCase 不依赖 UseCase |

### 架构评分改进

| 维度 | 原评分 | 修正后 |
|------|--------|--------|
| SRP 单一职责 | 50/100 | 90/100 |
| Entity 设计 | 60/100 | 95/100 |
| 可测试性 | 60/100 | 85/100 |
| 命名一致性 | 70/100 | 95/100 |
| Swift Concurrency | 70/100 | 90/100 |
| **总分** | **68/100** | **91/100** |
