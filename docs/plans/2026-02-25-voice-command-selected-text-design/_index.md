# 语音指令处理选中文本功能设计

**版本**: 2.0 (Reviewed)
**更新日期**: 2026-02-25
**Review 状态**: 已通过 Architecture Review，修正了 SRP 和 Entity 设计问题

---

## 概述

本设计文档描述了一个新功能：当用户选中某段文字并按住 Fn 键说话时，系统获取选中文本，将语音指令和选中文本发送给 LLM 处理，然后用处理结果替换选中的文本。

## 背景

当前 DIYTypeless 应用的工作流程：
1. 用户按住 Fn 键 → 开始录音
2. 用户松开 Fn 键 → 停止录音
3. Groq Whisper 转录音频
4. Gemini 润色文本
5. 粘贴到当前焦点元素

新需求希望在第 3-4 步之间增加一个分支：如果检测到有选中文本，则将语音作为**指令**处理选中文本，而非直接转录粘贴。

---

## 需求

### 功能需求

1. **选中文本检测**：录音完成后通过 Accessibility API 获取当前选中文本
2. **语音指令处理**：将转录后的语音内容作为指令，与选中文本一起发送给 LLM
3. **智能回退**：如果没有选中文本，回退到现有转录模式
4. **结果输出**：用 Cmd+V 粘贴覆盖选中文本
5. **完全开放指令**：不预设指令类型，让 LLM 理解用户意图

### 非功能需求

1. **延迟**：总处理时间应控制在 3-5 秒内（Groq 转录 + Gemini 处理）
2. **可靠性**：Accessibility API 失败时优雅回退
3. **隐私**：不处理密码字段（AXSecureTextField）的选中文本
4. **兼容性**：支持主流应用（Chrome、VS Code、Notes、Safari 等）

---

## 架构设计

### 整体流程

```
┌─────────────────────────────────────────────────────────────────┐
│                         用户操作流程                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. 用户选中文字 → 2. 按住 Fn 说话 → 3. 松开 Fn                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     RecordingState (ViewModel)                   │
│  - 在 handleKeyUp() 中编排流程                                   │
│  - 1. 获取选中文本（GetSelectedTextUseCase）                     │
│  - 2. 停止录音并转录（FFI）                                      │
│  - 3. 根据是否有选中文本决定后续流程                             │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────────────┐
│  有选中文本              │    │  无选中文本                      │
│  (Voice Command Mode)    │    │  (Fallback to Transcription)    │
└─────────────────────────┘    └─────────────────────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────────────┐
│  ProcessVoiceCommand    │    │  TranscriptionPipelineUseCase   │
│  UseCase                │    │  (existing)                     │
│  - 构建 Prompt          │    │                                 │
│  - 调用 Gemini          │    │                                 │
│  - 返回处理结果         │    │                                 │
└─────────────────────────┘    └─────────────────────────────────┘
              │                               │
              └───────────────┬───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  SystemTextOutputRepository                                      │
│  - 粘贴结果到光标位置（覆盖选中文本）                            │
└─────────────────────────────────────────────────────────────────┘
```

### Clean Architecture 分层

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  RecordingState (ViewModel)                             │   │
│  │  - 编排 UseCase 调用顺序                                │   │
│  │  - 决定执行 Voice Command 还是 Transcription 模式       │   │
│  │  - 管理 UI 状态                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Domain Layer                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  UseCases                                               │   │
│  │  ┌────────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ GetSelectedTextUseCase │  │ ProcessVoiceCommandUse │ │   │
│  │  │ (NEW)                  │  │ Case (NEW)             │ │   │
│  │  └────────────────────────┘  └────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Repositories (Protocols)                               │   │
│  │  ┌────────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ SelectedTextRepository │  │ LLMRepository          │ │   │
│  │  │ (NEW)                  │  │ (NEW)                  │ │   │
│  │  └────────────────────────┘  └────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Entities (贫血实体，只有数据)                           │   │
│  │  ┌────────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ SelectedTextContext    │  │ VoiceCommandResult     │ │   │
│  │  │ (NEW)                  │  │ (NEW)                  │ │   │
│  │  └────────────────────────┘  └────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Repositories (Implementations)                         │   │
│  │  ┌────────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ AccessibilitySelected  │  │ GeminiLLMRepository    │ │   │
│  │  │ TextRepository (NEW)   │  │ (NEW)                  │ │   │
│  │  └────────────────────────┘  └────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                          │
│  - FFI Bridge (Rust core)                                       │
│  - process_text_with_llm (新增 Rust 函数)                       │
└─────────────────────────────────────────────────────────────────┘
```

### 新增文件清单

**Swift 文件：**

| 文件路径 | 说明 |
|---------|------|
| `Domain/UseCases/GetSelectedTextUseCase.swift` | 获取选中文本用例 |
| `Domain/UseCases/ProcessVoiceCommandUseCase.swift` | 处理语音指令用例 |
| `Domain/Repositories/SelectedTextRepository.swift` | 选中文本仓库协议 |
| `Domain/Repositories/LLMRepository.swift` | LLM 调用仓库协议 |
| `Domain/Entities/SelectedTextContext.swift` | 选中文本上下文实体 |
| `Data/Repositories/AccessibilitySelectedTextRepository.swift` | Accessibility API 实现 |
| `Data/Repositories/GeminiLLMRepository.swift` | Gemini API 调用实现 |

**Rust 文件：**

| 文件路径 | 说明 |
|---------|------|
| `core/src/llm_processor.rs` | 通用 LLM 处理模块 |
| `core/src/lib.rs` | 导出新的 FFI 函数 |

---

## 详细设计

### 1. SelectedTextContext 实体（贫血实体）

```swift
// Domain/Entities/SelectedTextContext.swift
struct SelectedTextContext: Sendable {
    let text: String?
    let isEditable: Bool
    let isSecure: Bool
    let applicationName: String

    // 只有纯数据计算，无业务逻辑
    var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }
}

// 注意：isValidForProcessing 等业务逻辑移到 UseCase 中
```

**设计原则**：
- Entity 保持**贫血**（只有数据，无业务逻辑）
- `isValidForProcessing` 等业务规则放在 UseCase 中判断
- 遵循 Clean Architecture 的 Entity 定义

### 2. SelectedTextRepository 协议

```swift
// Domain/Repositories/SelectedTextRepository.swift
import Foundation

protocol SelectedTextRepository: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
```

**命名规范**：
- 遵循项目惯例，Repository 协议**不加 Protocol 后缀**
- 如：`ApiKeyRepository`（不是 `ApiKeyRepositoryProtocol`）

### 3. GetSelectedTextUseCase

```swift
// Domain/UseCases/GetSelectedTextUseCase.swift
import Foundation

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

**单一职责**：只负责"获取选中文本"一件事

### 4. ProcessVoiceCommandUseCase

```swift
// Domain/UseCases/ProcessVoiceCommandUseCase.swift
import Foundation

struct VoiceCommandResult: Sendable {
    let processedText: String
    let action: CommandAction
}

enum CommandAction: Sendable {
    case replaceSelection    // 替换选中文本
    case insertAtCursor      // 在光标处插入
    case copyToClipboard     // 仅复制
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

    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult {
        // 构建 Prompt
        let prompt = buildPrompt(command: transcription, selectedText: selectedText)

        // 调用 LLM
        let response = try await llmRepository.generate(
            apiKey: geminiKey,
            prompt: prompt,
            temperature: 0.3
        )

        // 返回结果
        return VoiceCommandResult(
            processedText: response,
            action: .replaceSelection  // 根据上下文决定
        )
    }

    private func buildPrompt(command: String, selectedText: String) -> String {
        """
        用户选中了以下文本：
        '''\(selectedText)'''

        用户说：\(command)

        请理解用户的意图，对选中的文本执行相应操作。
        只返回处理后的文本，不要解释，不要加引号。
        """
    }
}
```

**设计要点**：
- 不依赖其他 UseCase，只依赖 Repository
- 单一职责：处理语音指令并返回结果
- 不处理输出（粘贴/复制），只返回结果和推荐 action

### 5. LLMRepository 协议

```swift
// Domain/Repositories/LLMRepository.swift
import Foundation

protocol LLMRepository: Sendable {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String
}
```

### 6. AccessibilitySelectedTextRepository

```swift
// Data/Repositories/AccessibilitySelectedTextRepository.swift
import AppKit

final class AccessibilitySelectedTextRepository: SelectedTextRepository {
    func getSelectedText() async -> SelectedTextContext {
        // 在后台线程执行 Accessibility API 调用
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let context = self.performAccessibilityQuery()
                continuation.resume(returning: context)
            }
        }
    }

    private func performAccessibilityQuery() -> SelectedTextContext {
        let systemWide = AXUIElementCreateSystemWide()

        // 获取当前应用名称
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        // 获取焦点元素
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return SelectedTextContext(
                text: nil,
                isEditable: false,
                isSecure: false,
                applicationName: appName
            )
        }

        let axElement = element as! AXUIElement

        // 检查是否是安全文本字段（密码）
        let isSecure = checkIfSecureTextField(axElement)
        if isSecure {
            return SelectedTextContext(
                text: nil,
                isEditable: false,
                isSecure: true,
                applicationName: appName
            )
        }

        // 检查是否可编辑
        let isEditable = checkIfEditable(axElement)

        // 获取选中文本
        var selectedText: String?

        // 方法1: 直接读取 kAXSelectedTextAttribute
        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )

        if selectedResult == .success, let text = selectedValue as? String {
            selectedText = text
        }

        return SelectedTextContext(
            text: selectedText,
            isEditable: isEditable,
            isSecure: false,
            applicationName: appName
        )
    }

    private func checkIfSecureTextField(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        if roleResult == .success, let role = roleValue as? String {
            return role == (kAXSecureTextFieldRole as String)
        }

        // 备选：检查子角色
        var subroleValue: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )

        if subroleResult == .success, let subrole = subroleValue as? String {
            return subrole.contains("Secure")
        }

        return false
    }

    private func checkIfEditable(_ element: AXUIElement) -> Bool {
        var editableValue: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(
            element,
            "AXEditable" as CFString,
            &editableValue
        )

        if editableResult == .success, let isEditable = editableValue as? Bool {
            return isEditable
        }

        // 检查角色
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        if roleResult == .success, let role = roleValue as? String {
            let editableRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                "AXSearchField",
                kAXComboBoxRole as String
            ]
            return editableRoles.contains(role)
        }

        return false
    }
}
```

**关键改进**：
- Accessibility API 调用在 `DispatchQueue.global(qos: .userInitiated)` 执行
- 不是主线程，避免阻塞 UI

### 7. GeminiLLMRepository

```swift
// Data/Repositories/GeminiLLMRepository.swift
import Foundation

final class GeminiLLMRepository: LLMRepository {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processTextWithLLM(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: Float(temperature ?? 0.3)
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### 8. RecordingState 集成（ViewModel 编排）

```swift
// State/RecordingState.swift 修改
@MainActor
@Observable
final class RecordingState {
    // 新增依赖
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol
    private let transcriptionUseCase: TranscriptionUseCaseProtocol
    private let textOutputRepository: TextOutputRepository

    init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        keyMonitoringRepository: KeyMonitoringRepository,
        textOutputRepository: TextOutputRepository = SystemTextOutputRepository(),
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol = GetSelectedTextUseCase(),
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol = ProcessVoiceCommandUseCase(),
        transcriptionUseCase: TranscriptionUseCaseProtocol = TranscriptionPipelineUseCase()
    ) {
        // ... 现有初始化 ...
        self.getSelectedTextUseCase = getSelectedTextUseCase
        self.processVoiceCommandUseCase = processVoiceCommandUseCase
        self.transcriptionUseCase = transcriptionUseCase
        self.textOutputRepository = textOutputRepository
    }

    private func handleKeyUp() async {
        guard isRecording else { return }

        isRecording = false
        isProcessing = true

        do {
            guard let groqKey = apiKeyRepository.loadKey(for: .groq),
                  let geminiKey = apiKeyRepository.loadKey(for: .gemini) else {
                throw RecordingError.missingAPIKey
            }

            // 1. 获取选中文本（并行执行）
            let selectedTextContext = await getSelectedTextUseCase.execute()

            // 2. 停止录音并获取音频
            let wavData = try await stopRecordingAsync()

            // 3. 转录音频
            let transcription = try await transcribeAsync(
                apiKey: groqKey,
                wavBytes: wavData.bytes,
                language: nil
            )

            // 4. 根据是否有选中文本决定处理路径（ViewModel 编排）
            if shouldUseVoiceCommandMode(selectedTextContext) {
                // Voice Command Mode
                try await handleVoiceCommandMode(
                    transcription: transcription,
                    selectedText: selectedTextContext.text!,
                    geminiKey: geminiKey
                )
            } else {
                // Transcription Mode（回退）
                try await handleTranscriptionMode(
                    transcription: transcription,
                    groqKey: groqKey,
                    geminiKey: geminiKey
                )
            }

        } catch {
            statusText = "Error: \(error.localizedDescription)"
        }

        isProcessing = false

        // 延迟隐藏胶囊
        try? await Task.sleep(for: .seconds(statusText.hasPrefix("Error") ? 2.0 : 1.2))
        if !isRecording && !isProcessing {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isShowingCapsule = false
            }
        }
    }

    // MARK: - 业务规则判断（从 Entity 移到 ViewModel/UseCase）

    private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool {
        context.hasSelection && !context.isSecure
    }

    // MARK: - Voice Command Mode

    private func handleVoiceCommandMode(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws {
        let result = try await processVoiceCommandUseCase.execute(
            transcription: transcription,
            selectedText: selectedText,
            geminiKey: geminiKey
        )

        let outputResult = textOutputRepository.deliver(text: result.processedText)

        statusText = "Voice command: \"\(transcription)\" applied"
        resultText = result.processedText
    }

    // MARK: - Transcription Mode (Fallback)

    private func handleTranscriptionMode(
        transcription: String,
        groqKey: String,
        geminiKey: String
    ) async throws {
        let result = try await transcriptionUseCase.execute(
            groqKey: groqKey,
            geminiKey: geminiKey,
            context: appContext?.description
        )

        statusText = result.outputResult == .pasted
            ? "Pasted"
            : "Copied to clipboard"
        resultText = result.polishedText
    }
}
```

**关键改进**：
- ViewModel 负责**编排** UseCase 调用顺序
- 业务规则 `shouldUseVoiceCommandMode` 放在 ViewModel（或单独的 Validator）
- 不创建臃肿的 UseCase，保持每个 UseCase 单一职责

---

## Rust FFI 设计

### llm_processor.rs

```rust
// core/src/llm_processor.rs
use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use reqwest::StatusCode;
use serde::Deserialize;
use std::thread::sleep;
use std::time::Duration;

#[derive(Deserialize)]
struct GeminiResponse {
    candidates: Vec<GeminiCandidate>,
}

#[derive(Deserialize)]
struct GeminiCandidate {
    content: GeminiContent,
}

#[derive(Deserialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
}

#[derive(Deserialize)]
struct GeminiPart {
    text: Option<String>,
}

/// 通用 LLM 文本处理函数
pub fn process_text_with_llm(
    api_key: &str,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    let client = get_http_client();
    let url = format!("{GEMINI_API_URL}/{GEMINI_MODEL}:generateContent");

    let mut body = serde_json::json!({
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ]
    });

    // 添加系统指令
    if let Some(instruction) = system_instruction {
        body["systemInstruction"] = serde_json::json!({
            "parts": [{"text": instruction}]
        });
    }

    // 添加生成配置
    let mut generation_config = serde_json::Map::new();
    if let Some(temp) = temperature {
        generation_config.insert("temperature".to_string(), serde_json::json!(temp));
    }
    generation_config.insert("maxOutputTokens".to_string(), serde_json::json!(4096));
    body["generationConfig"] = serde_json::Value::Object(generation_config);

    // 重试逻辑
    for attempt in 0..3 {
        let response = client
            .post(&url)
            .header("x-goog-api-key", api_key)
            .json(&body)
            .send();

        match response {
            Ok(resp) if resp.status() == StatusCode::OK => {
                let payload: GeminiResponse = resp.json()?;
                let text = payload
                    .candidates
                    .get(0)
                    .and_then(|c| c.content.parts.get(0))
                    .and_then(|p| p.text.clone())
                    .ok_or(CoreError::EmptyResponse)?;
                return Ok(text.trim().to_string());
            }
            Ok(resp) if resp.status() == StatusCode::TOO_MANY_REQUESTS
                || resp.status().is_server_error() => {
                let backoff = 2u64.pow(attempt);
                sleep(Duration::from_secs(backoff));
                continue;
            }
            Ok(resp) => {
                return Err(CoreError::Api(format!(
                    "Gemini API error: HTTP {}",
                    resp.status()
                )));
            }
            Err(err) => {
                if attempt < 2 {
                    let backoff = 2u64.pow(attempt);
                    sleep(Duration::from_secs(backoff));
                    continue;
                }
                return Err(CoreError::Http(err.to_string()));
            }
        }
    }

    Err(CoreError::Api("Gemini API retries exceeded".to_string()))
}
```

### lib.rs 导出

```rust
// core/src/lib.rs
mod llm_processor;

// 导出新的 FFI 函数
#[uniffi::export]
pub fn process_text_with_llm(
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm(
        &api_key,
        &prompt,
        system_instruction.as_deref(),
        temperature,
    )
}
```

---

## 错误处理策略

### 选中文本获取失败

| 场景 | 行为 |
|------|------|
| Accessibility API 返回 nil | 回退到转录模式 |
| 无 Accessibility 权限 | 显示错误提示，引导用户开启权限 |
| 目标应用不支持 AXSelectedText | 回退到转录模式（静默） |
| 选中密码字段 | 显示错误提示，不发送敏感信息到 LLM |

### LLM API 失败

| 场景 | 行为 |
|------|------|
| API 超时 (30s) | 显示超时错误，保留原始选中文本 |
| API 返回空响应 | 显示错误，保留原始选中文本 |
| 网络错误 | 重试 3 次后显示错误 |

---

## 隐私和安全考虑

1. **密码字段保护**：通过 `kAXSecureTextFieldRole` 检测密码输入框，拒绝处理
2. **文本长度限制**：超过 4000 tokens 的选中文本将被截断，并添加 "(truncated)" 标记
3. **敏感信息提示**：首次使用时提示用户选中文本将发送到云端 LLM
4. **本地优先**：音频处理（录音）始终在本地完成，仅文本发送到云端

---

## Review 修正总结

### 已修正的问题

| 问题 | 修正方案 |
|------|----------|
| UseCase 过于臃肿 | 拆分为 `GetSelectedTextUseCase` + `ProcessVoiceCommandUseCase` |
| Entity 包含业务逻辑 | 移除 `isValidForProcessing`，移到 ViewModel |
| Repository 命名不一致 | 改为 `SelectedTextRepository`（无 Protocol 后缀） |
| Accessibility API 主线程执行 | 改为后台线程 `DispatchQueue.global(qos: .userInitiated)` |
| UseCase 依赖 UseCase | ViewModel 负责编排，UseCase 只依赖 Repository |

### 架构评分改进

| 维度 | 原评分 | 修正后 | 改进 |
|------|--------|--------|------|
| SRP 单一职责 | 50/100 | 90/100 | UseCase 拆分，职责单一 |
| Entity 设计 | 60/100 | 95/100 | 贫血实体，业务逻辑上移 |
| 可测试性 | 60/100 | 85/100 | 依赖减少，易于 Mock |
| 命名一致性 | 70/100 | 95/100 | 遵循项目惯例 |
| Swift Concurrency | 70/100 | 90/100 | 后台线程处理 |

---

## Design Documents

- [BDD Specifications](./bdd-specs.md) - 行为场景和测试策略
- [Architecture](./architecture.md) - 系统架构和组件详情
- [Best Practices](./best-practices.md) - 实现细节和最佳实践

---

## 后续优化方向

1. **专用指令模式**：识别常见指令（翻译、总结、润色），提供更快速的专用处理路径
2. **指令预览**：在发送给 LLM 前显示"理解的用户意图"，让用户确认
3. **历史记录**：保存用户的语音指令历史，支持快捷重复使用
4. **多模态支持**：直接发送音频到 Gemini 2.0 Flash，跳过转录步骤
