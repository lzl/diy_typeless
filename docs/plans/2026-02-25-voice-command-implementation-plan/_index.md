# 语音指令处理选中文本 - 实现计划

**版本**: 1.0
**创建日期**: 2026-02-25
**设计文档**: `docs/plans/2026-02-25-voice-command-selected-text-design/`

---

## 目标

实现"语音指令处理选中文本"功能，允许用户：
1. 选中任意应用中的文本
2. 按住 Fn 键并说出语音指令
3. 系统自动用 LLM 处理选中文本并替换结果

---

## 架构概述

### Clean Architecture 分层

```
Presentation (RecordingState)
    ↓ depends on
Domain (UseCases + Repository Protocols + Entities)
    ↓ depends on
Data (Repository Implementations)
    ↓ depends on
Infrastructure (Rust FFI)
```

### 关键组件

| 组件 | 文件 | 职责 |
|------|------|------|
| `SelectedTextContext` | Entity | 选中文本数据封装 |
| `GetSelectedTextUseCase` | UseCase | 获取选中文本 |
| `ProcessVoiceCommandUseCase` | UseCase | 处理语音指令 |
| `AccessibilitySelectedTextRepository` | Repository | AX API 调用 |
| `GeminiLLMRepository` | Repository | LLM FFI 包装 |
| `process_text_with_llm` | Rust FFI | 通用 LLM 处理 |

---

## 执行计划

### Phase 1: Rust Core 实现

| 任务 | 文件 | 说明 |
|------|------|------|
| [Task 001](./task-001-rust-llm-processor.md) | `core/src/llm_processor.rs` | 通用 LLM 处理模块 |
| [Task 002](./task-002-rust-ffi-export.md) | `core/src/lib.rs` | FFI 导出函数 |

### Phase 2: Domain 层 (Swift)

| 任务 | 文件 | 说明 |
|------|------|------|
| [Task 003](./task-003-swift-entity-selected-text-context.md) | `SelectedTextContext.swift` | 贫血实体 |
| [Task 004](./task-004-swift-entity-voice-command-result.md) | `VoiceCommandResult.swift` | 结果实体 |
| [Task 005](./task-005-swift-repository-selected-text.md) | `SelectedTextRepository.swift` | 选中文本协议 |
| [Task 006](./task-006-swift-repository-llm.md) | `LLMRepository.swift` | LLM 协议 |
| [Task 007](./task-007-swift-usecase-get-selected-text.md) | `GetSelectedTextUseCase.swift` | 获取选中文本用例 |
| [Task 008](./task-008-swift-usecase-process-voice-command.md) | `ProcessVoiceCommandUseCase.swift` | 处理语音指令用例 |

### Phase 3: Data 层 (Swift)

| 任务 | 文件 | 说明 |
|------|------|------|
| [Task 009](./task-009-swift-repository-accessibility.md) | `AccessibilitySelectedTextRepository.swift` | AX API 实现 |
| [Task 010](./task-010-swift-repository-gemini.md) | `GeminiLLMRepository.swift` | Gemini FFI 包装 |

### Phase 4: Presentation 层 (Swift)

| 任务 | 文件 | 说明 |
|------|------|------|
| [Task 011](./task-011-swift-viewmodel-recording-state.md) | `RecordingState.swift` | ViewModel 集成与编排 |

### Phase 5: 测试

| 任务 | 说明 |
|------|------|
| [Task 012](./task-012-test-get-selected-text-usecase.md) | GetSelectedTextUseCase 单元测试 |
| [Task 013](./task-013-test-process-voice-command-usecase.md) | ProcessVoiceCommandUseCase 单元测试 |
| [Task 014](./task-014-test-recording-state.md) | RecordingState 编排逻辑测试 |
| [Task 015](./task-015-test-rust-llm-processor.md) | Rust llm_processor 测试 |

---

## 实现顺序

```
Phase 1: Rust Core
    ├── Task 001: llm_processor.rs (无依赖)
    └── Task 002: lib.rs FFI 导出 (依赖 Task 001)

Phase 2: Domain 层
    ├── Task 003: SelectedTextContext (无依赖)
    ├── Task 004: VoiceCommandResult (无依赖)
    ├── Task 005: SelectedTextRepository (无依赖)
    ├── Task 006: LLMRepository (无依赖)
    ├── Task 007: GetSelectedTextUseCase (依赖 Task 003, 005)
    └── Task 008: ProcessVoiceCommandUseCase (依赖 Task 004, 006)

Phase 3: Data 层
    ├── Task 009: AccessibilitySelectedTextRepository (依赖 Task 005, 003)
    └── Task 010: GeminiLLMRepository (依赖 Task 006, Rust FFI)

Phase 4: Presentation 层
    └── Task 011: RecordingState (依赖 Task 007, 008, 009, 010)

Phase 5: 测试
    ├── Task 012: GetSelectedTextUseCaseTests (依赖 Task 007)
    ├── Task 013: ProcessVoiceCommandUseCaseTests (依赖 Task 008)
    ├── Task 014: RecordingStateTests (依赖 Task 011)
    └── Task 015: Rust llm_processor tests (依赖 Task 001)
```

---

## 验证方式

### 构建验证
```bash
# Rust
cargo build -p diy_typeless_core --release

# Swift (CLI 验证)
./scripts/dev-loop.sh --testing
```

### 测试验证
```bash
# Swift 测试
cd app/DIYTypeless && xcodebuild test -scheme DIYTypeless -destination 'platform=macOS'

# Rust 测试
cargo test -p diy_typeless_core
```

### 功能验证 (BDD)
参考 `docs/plans/2026-02-25-voice-command-selected-text-design/bdd-specs.md` 中的场景：
- Scenario: 选中文本语音指令处理并粘贴结果
- Scenario: 无选中文本时回退到转录模式
- Scenario: 选中密码字段文本

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| Accessibility API 不稳定 | 多层回退策略 (kAXSelectedTextAttribute → value+range) |
| LLM 延迟过高 | 连接预热，超时控制 (30s) |
| 隐私泄露 | 密码字段检测，不发送敏感信息 |
| 编译失败 | 每 Task 完成后立即编译验证 |

---

## 提交规范

每个 Task 完成后提交：
```
feat(scope): description

- 详细变更说明

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

示例：
```
feat(core): add llm_processor module for generic text processing

- Add process_text_with_llm function
- Implement retry logic with exponential backoff
- Add temperature and system_instruction support

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
