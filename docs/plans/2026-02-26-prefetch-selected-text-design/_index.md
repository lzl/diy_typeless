# Prefetch Selected Text Design

## Context

当前语音输入流程中，获取用户选中文本（`getSelectedTextUseCase.execute()`）是在松开 Fn 键后才启动的，与停止录音并行执行。由于 Accessibility API 查询和 Clipboard 方法（特别是轮询等待）需要几百毫秒，这导致用户松开 Fn 键后需要等待才能看到处理状态更新。

用户反馈这个延迟影响了体验，希望将获取选中文本的操作前置到 Fn 键按下期间。

## Requirements

### Functional Requirements

1. **延迟预取**：用户按住 Fn 键 300ms 后，自动启动获取选中文本的操作
2. **短按取消**：300ms 内松开 Fn 键，取消预取任务，不获取选中文本（直接使用转写模式）
3. **结果复用**：松开 Fn 键时，直接使用预取的结果（无论是否成功获取到文本）
4. **模式判断**：松开时根据预取结果的 `hasSelection` 判断走语音命令模式还是转写模式
5. **选区不变性**：预取期间用户改变选区，仍使用预取时的选区（接受此风险以简化实现）

### Non-Functional Requirements

1. **向后兼容**：不影响现有测试和外部接口
2. **可取消性**：预取任务必须可取消，避免资源浪费
3. **线程安全**：正确处理 `@MainActor` 和后台线程的协作

## Rationale

### Why 300ms?

- 人类快速按键的典型时长 < 200ms
- 300ms 作为分水岭可以区分"短按取消"和"长按输入"
- 给用户足够时间调整选区后再开始预取

### Why Accept Stale Selection?

- 语音输入期间用户通常专注于说话，不会频繁调整选区
- 复杂的一致性检查（如选区指纹对比）会增加代码复杂度和延迟
- 如果用户真的改变了选区，直接取消语音输入重新开始成本很低

## Detailed Design

### State Changes in RecordingState

```swift
@MainActor
@Observable
final class RecordingState {
    // ... existing properties ...

    // MARK: - Prefetch State
    private var preselectedContext: SelectedTextContext?
    private var prefetchTask: Task<Void, Never>?
    private static let prefetchDelay: Duration = .milliseconds(300)
}
```

### Flow Changes

#### Current Flow (松开 Fn 后)

```
handleKeyDown() -> 开始录音
                         ↓
                    用户按住说话
                         ↓
handleKeyUp() ──→ 并行获取选中文本 + 停止录音
                         ↓
              根据结果判断模式 → 处理
```

#### New Flow (延迟预取)

```
handleKeyDown() -> 开始录音
       │
       └──→ 启动 300ms 延迟任务
                │
                ├── 300ms 内松开 → 取消任务，不走语音命令模式
                │
                └── 300ms 后启动获取选中文本 ──→ 结果存入 preselectedContext
                                                         ↓
handleKeyUp() ─────────────────────────────────────── 直接使用 preselectedContext
                                                         ↓
                                              根据 hasSelection 判断模式
```

### Implementation Details

#### handleKeyDown Changes

```swift
func handleKeyDown() async {
    // ... existing validation ...

    // Start prefetch after 300ms delay
    prefetchTask = Task { [weak self] in
        try? await Task.sleep(for: Self.prefetchDelay)

        guard let self, !Task.isCancelled else { return }

        // Start prefetching selected text
        let context = await getSelectedTextUseCase.execute()

        guard !Task.isCancelled else { return }
        self.preselectedContext = context
    }

    // ... start recording ...
}
```

#### handleKeyUp Changes

```swift
func handleKeyUp() async {
    guard isRecording else { return }

    // Cancel prefetch if still running (short press case)
    prefetchTask?.cancel()
    prefetchTask = nil

    // ... existing setup ...

    do {
        // Stop recording (no longer parallel with getSelectedText)
        let audio = try await stopRecordingUseCase.execute()

        // Use preselected context if available, otherwise empty context
        let context = preselectedContext ?? SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: ""
        )

        // Clear preselected context for next session
        preselectedContext = nil

        // ... rest of flow uses context directly ...
    }
}
```

### SelectedTextContext Factory Method

Add convenience initializer for empty context:

```swift
extension SelectedTextContext {
    static var empty: SelectedTextContext {
        SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: ""
        )
    }
}
```

### Race Condition Handling

1. **预取完成前松开**：使用 `preselectedContext ?? .empty`
2. **预取进行中松开**：取消任务，使用 `.empty`
3. **预取完成后松开**：使用缓存的 `preselectedContext`

## Testing Strategy

### Unit Test Cases

1. **正常预取流程**：按住 >300ms，预取完成，松开后使用预取结果
2. **短按取消**：按住 <300ms，预取任务被取消，使用空上下文
3. **预取进行中松开**：预取已开始但未完成，取消任务，使用空上下文
4. **多次快速按键**：确保 `prefetchTask` 和 `preselectedContext` 正确重置

### Manual Test Scenarios

1. 选中文字，长按 Fn 说话，确认语音命令模式快速启动
2. 不选文字，长按 Fn 说话，确认转写模式正常工作
3. 短按 Fn (<300ms)，确认进入转写模式
4. 选中文本后改变选区再松开，确认使用预取时的旧选区

## Design Documents

- [BDD Specifications](./bdd-specs.md) - Behavior scenarios and testing strategy
- [Architecture](./architecture.md) - System architecture and component details
- [Best Practices](./best-practices.md) - Security, performance, and code quality guidelines
