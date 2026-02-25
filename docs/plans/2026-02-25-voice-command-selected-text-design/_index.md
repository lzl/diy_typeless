# 语音指令处理选中文本功能设计

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
│                     RecordingState (Swift)                       │
│  - handleKeyUp() 触发处理流程                                   │
│  - 先获取选中文本（Accessibility API）                           │
│  - 再停止录音获取音频数据                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              SelectedTextCommandUseCase (Swift)                  │
│  - 协调整个处理流程                                              │
│  - 根据是否有选中文本决定执行路径                                │
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
│  1. Groq 转录语音为指令  │    │  1. Groq 转录语音               │
│  2. 构建 Prompt         │    │  2. Gemini 润色                 │
│  3. Gemini 处理选中文本  │    │  3. 粘贴结果                    │
│  4. 粘贴结果            │    │                                 │
└─────────────────────────┘    └─────────────────────────────────┘
```

### Clean Architecture 分层

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                          │
│  - RecordingState: 协调 UI 状态，持有 UseCase                   │
│  - ProcessingCapsule: 显示处理进度和状态                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Domain Layer                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  UseCases                                               │   │
│  │  - SelectedTextCommandUseCaseProtocol                  │   │
│  │  - SelectedTextCommandUseCase                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Repositories (Protocols)                               │   │
│  │  - SelectedTextRepositoryProtocol                      │   │
│  │  - TextOutputRepositoryProtocol                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Entities                                               │   │
│  │  - SelectedTextContext                                 │   │
│  │  - VoiceCommandResult                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Repositories (Implementations)                         │   │
│  │  - AccessibilitySelectedTextRepository                 │   │
│  │  - SystemTextOutputRepository (现有)                   │   │
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
| `Domain/UseCases/SelectedTextCommandUseCase.swift` | 核心用例实现 |
| `Domain/Repositories/SelectedTextRepositoryProtocol.swift` | 选中文本仓库协议 |
| `Domain/Entities/SelectedTextContext.swift` | 选中文本上下文实体 |
| `Data/Repositories/AccessibilitySelectedTextRepository.swift` | Accessibility API 实现 |

**Rust 文件：**

| 文件路径 | 说明 |
|---------|------|
| `core/src/llm_processor.rs` | 通用 LLM 处理模块 |
| `core/src/lib.rs` | 导出新的 FFI 函数 |

## 详细设计

### 1. SelectedTextContext 实体

```swift
// Domain/Entities/SelectedTextContext.swift
struct SelectedTextContext: Sendable {
    let text: String?
    let isEditable: Bool
    let isSecure: Bool
    let applicationName: String

    var hasSelection: Bool {
        guard let text = text else { return false }
        return !text.isEmpty
    }

    var isValidForProcessing: Bool {
        hasSelection && !isSecure
    }
}
```

### 2. SelectedTextRepositoryProtocol

```swift
// Domain/Repositories/SelectedTextRepositoryProtocol.swift
protocol SelectedTextRepositoryProtocol: Sendable {
    func getSelectedText() async -> SelectedTextContext
}
```

### 3. SelectedTextCommandUseCase

```swift
// Domain/UseCases/SelectedTextCommandUseCase.swift
protocol SelectedTextCommandUseCaseProtocol: Sendable {
    func execute(
        groqKey: String,
        geminiKey: String,
        context: String?
    ) async throws -> SelectedTextCommandResult
}

struct SelectedTextCommandResult: Sendable {
    let outputText: String
    let mode: ProcessingMode
    let outputResult: OutputResult
}

enum ProcessingMode: Sendable {
    case voiceCommand(originalText: String, instruction: String)
    case transcription
}

final class SelectedTextCommandUseCase: SelectedTextCommandUseCaseProtocol {
    private let selectedTextRepository: SelectedTextRepositoryProtocol
    private let textOutputRepository: TextOutputRepositoryProtocol
    private let baseTranscriptionUseCase: TranscriptionUseCaseProtocol

    func execute(
        groqKey: String,
        geminiKey: String,
        context: String?
    ) async throws -> SelectedTextCommandResult {
        // 1. 获取选中文本
        let selectedTextContext = await selectedTextRepository.getSelectedText()

        // 2. 停止录音并获取音频
        let wavData = try await stopRecordingAsync()

        // 3. 转录音频（无论是否有选中文本都需要）
        let voiceText = try await transcribeAsync(
            apiKey: groqKey,
            wavBytes: wavData.bytes,
            language: nil
        )

        // 4. 根据是否有选中文本决定处理路径
        if selectedTextContext.isValidForProcessing {
            // Voice Command Mode
            let processedText = try await processWithLLM(
                apiKey: geminiKey,
                instruction: voiceText,
                selectedText: selectedTextContext.text!
            )

            let outputResult = textOutputRepository.deliver(text: processedText)

            return SelectedTextCommandResult(
                outputText: processedText,
                mode: .voiceCommand(
                    originalText: selectedTextContext.text!,
                    instruction: voiceText
                ),
                outputResult: outputResult
            )
        } else {
            // Fallback to Transcription Mode
            let polishedText = try await polishAsync(
                apiKey: geminiKey,
                rawText: voiceText,
                context: context
            )

            let outputResult = textOutputRepository.deliver(text: polishedText)

            return SelectedTextCommandResult(
                outputText: polishedText,
                mode: .transcription,
                outputResult: outputResult
            )
        }
    }

    private func processWithLLM(
        apiKey: String,
        instruction: String,
        selectedText: String
    ) async throws -> String {
        let prompt = """
        用户选中了以下文本：
        '''\(selectedText)'''

        用户说：\(instruction)

        请理解用户的意图，对选中的文本执行相应操作。
        只返回处理后的文本，不要解释，不要加引号。
        """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processTextWithLLM(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: 0.3
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

### 4. AccessibilitySelectedTextRepository

```swift
// Data/Repositories/AccessibilitySelectedTextRepository.swift
import AppKit

final class AccessibilitySelectedTextRepository: SelectedTextRepositoryProtocol {
    func getSelectedText() async -> SelectedTextContext {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let context = self.readSelectedTextSync()
                continuation.resume(returning: context)
            }
        }
    }

    private func readSelectedTextSync() -> SelectedTextContext {
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

        // 备选：检查 AXSecureTextField 子角色
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

### 5. Rust LLM Processor

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
    // 限制输出长度，避免过度生成
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

### 6. lib.rs 导出

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

### 7. RecordingState 集成

```swift
// State/RecordingState.swift 修改
@MainActor
@Observable
final class RecordingState {
    // 新增依赖
    private let selectedTextCommandUseCase: SelectedTextCommandUseCaseProtocol

    init(
        // ... 现有参数 ...
        selectedTextCommandUseCase: SelectedTextCommandUseCaseProtocol = SelectedTextCommandUseCase()
    ) {
        // ... 现有初始化 ...
        self.selectedTextCommandUseCase = selectedTextCommandUseCase
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

            // 使用新的 UseCase 处理流程
            let result = try await selectedTextCommandUseCase.execute(
                groqKey: groqKey,
                geminiKey: geminiKey,
                context: appContext?.description
            )

            // 根据处理模式显示不同状态
            switch result.mode {
            case .voiceCommand(let original, let instruction):
                statusText = "Voice command: \"\(instruction)\" applied"
            case .transcription:
                statusText = result.outputResult == .pasted
                    ? "Pasted"
                    : "Copied to clipboard"
            }

            resultText = result.outputText

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
}
```

## 错误处理策略

### 选中文本获取失败

| 场景 | 行为 |
|------|------|
| Accessibility API 返回 nil | 回退到转录模式 |
| 无 Accessibility 权限 | 显示错误提示，引导用户开启权限 |
| 目标应用不支持 AXSelectedText | 回退到转录模式 |
| 选中密码字段 | 显示错误提示，不发送敏感信息到 LLM |

### LLM API 失败

| 场景 | 行为 |
|------|------|
| API 超时 (30s) | 显示超时错误，保留原始选中文本 |
| API 返回空响应 | 显示错误，保留原始选中文本 |
| 网络错误 | 重试 3 次后显示错误 |

## 隐私和安全考虑

1. **密码字段保护**：通过 `kAXSecureTextFieldRole` 检测密码输入框，拒绝处理
2. **文本长度限制**：超过 4000 tokens 的选中文本将被截断，并添加 "(truncated)" 标记
3. **敏感信息提示**：首次使用时提示用户选中文本将发送到云端 LLM
4. **本地优先**：音频处理（录音）始终在本地完成，仅文本发送到云端

## 性能优化

1. **连接预热**：在 Fn 按下时预热 Groq 和 Gemini 连接
2. **并行执行**：音频上传和选中文本获取可以并行进行
3. **缓存策略**：对于相同的选中文本和指令，可以考虑缓存结果（未来优化）

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Accessibility API 不稳定 | 高 | 实现多层回退（直接读 selectedText → 读 value+range → 回退转录） |
| LLM 理解错误指令 | 中 | 使用低 temperature (0.3)，Prompt 中明确要求"只返回处理后的文本" |
| 延迟过高影响体验 | 中 | 优化连接预热，考虑添加"处理中"进度指示 |
| 隐私泄露 | 高 | 密码字段检测，文本长度限制，用户明确提示 |

## Design Documents

- [BDD Specifications](./bdd-specs.md) - 行为场景和测试策略
- [Architecture](./architecture.md) - 系统架构和组件详情
- [Best Practices](./best-practices.md) - 实现细节和最佳实践

## 后续优化方向

1. **专用指令模式**：识别常见指令（翻译、总结、润色），提供更快速的专用处理路径
2. **指令预览**：在发送给 LLM 前显示"理解的用户意图"，让用户确认
3. **历史记录**：保存用户的语音指令历史，支持快捷重复使用
4. **多模态支持**：直接发送音频到 Gemini 2.0 Flash，跳过转录步骤
