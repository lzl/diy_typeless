# UseCase 拆分实施计划

## 目标
将 `TranscriptionPipelineUseCase` 拆分为三个独立的 UseCase，让 `RecordingState` 完全掌控流程和状态。

## 当前架构问题
1. `TranscriptionPipelineUseCase.execute()` 是黑盒，内部包含3个步骤
2. `.transcribing` 状态停留过久，`.polishing` 状态几乎不可见
3. Voice command 模式下 `.processingCommand` 没有进度条（代码有动画但无 overlay）

---

## Phase 1: Domain 层变更

### 1.1 删除/重命名旧文件

**文件**: `Domain/UseCases/TranscriptionUseCase.swift`
- 当前包含 `TranscriptionResult` 实体和 `TranscriptionUseCaseProtocol`
- 重命名为 `TranscriptionEntities.swift`，仅保留实体
- 删除旧的 `TranscriptionUseCaseProtocol`（将被新协议替代）

**文件**: `Domain/UseCases/TranscriptionPipelineUseCase.swift`
- 当前包含 `TranscriptionPipelineUseCase` 实现和 `RecordingControlUseCase`
- 拆分为独立文件，见 Phase 2

### 1.2 定义新的 UseCase 协议

**新文件**: `Domain/UseCases/StopRecordingUseCase.swift`

```swift
import Foundation

/// Entity representing WAV audio data from stopped recording
struct WavData: Sendable {
    let bytes: Data
}

/// Protocol for stopping recording and retrieving audio data
protocol StopRecordingUseCaseProtocol: Sendable {
    /// Stops the current recording and returns the WAV audio data
    /// - Returns: WAV audio data
    /// - Throws: RecordingError if no recording is in progress or stop fails
    func execute() async throws -> WavData
}

enum RecordingError: Error {
    case notRecording
    case stopFailed(String)
    case invalidAudioData
}
```

**新文件**: `Domain/UseCases/TranscribeAudioUseCase.swift`

```swift
import Foundation

/// Protocol for transcribing audio to text
protocol TranscribeAudioUseCaseProtocol: Sendable {
    /// Transcribes audio data to raw text
    /// - Parameters:
    ///   - wavData: The WAV audio data to transcribe
    ///   - apiKey: Groq API key
    ///   - language: Optional language hint (e.g., "zh", "en")
    /// - Returns: Raw transcribed text
    /// - Throws: TranscriptionError if transcription fails
    func execute(wavData: WavData, apiKey: String, language: String?) async throws -> String
}

enum TranscriptionError: Error {
    case emptyAudio
    case apiError(String)
    case decodingFailed
}
```

**新文件**: `Domain/UseCases/PolishTextUseCase.swift`

```swift
import Foundation

/// Protocol for polishing transcribed text
protocol PolishTextUseCaseProtocol: Sendable {
    /// Polishes raw transcribed text using LLM
    /// - Parameters:
    ///   - rawText: The raw text from transcription
    ///   - apiKey: Gemini API key
    ///   - context: Optional context about the active application
    /// - Returns: Polished text
    /// - Throws: PolishingError if polishing fails
    func execute(rawText: String, apiKey: String, context: String?) async throws -> String
}

enum PolishingError: Error {
    case emptyInput
    case apiError(String)
    case invalidResponse
}
```

**修改文件**: `Domain/UseCases/TranscriptionEntities.swift`（原 `TranscriptionUseCase.swift`）

```swift
import Foundation

/// Result of the complete transcription pipeline
struct TranscriptionResult: Sendable {
    let rawText: String
    let polishedText: String
    let outputResult: OutputResult
}

/// Output delivery result
enum OutputResult: Sendable, Equatable {
    case pasted
    case copied
}
```

**保留文件**: `Domain/UseCases/RecordingControlUseCase.swift`

将 `RecordingControlUseCase` 从 `TranscriptionPipelineUseCase.swift` 中提取出来：

```swift
import Foundation

protocol RecordingControlUseCaseProtocol: Sendable {
    func startRecording() async throws
    func warmupConnections() async
}
```

---

## Phase 2: Data 层变更

### 2.1 实现新的 UseCase

**新文件**: `Data/UseCases/StopRecordingUseCase.swift`

```swift
import Foundation

final class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    func execute() async throws -> WavData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let wavData = try stopRecording()
                    continuation.resume(returning: wavData)
                } catch {
                    continuation.resume(throwing: RecordingError.stopFailed(error.localizedDescription))
                }
            }
        }
    }
}
```

**新文件**: `Data/UseCases/TranscribeAudioUseCase.swift`

```swift
import Foundation

final class TranscribeAudioUseCase: TranscribeAudioUseCaseProtocol {
    func execute(wavData: WavData, apiKey: String, language: String?) async throws -> String {
        guard !wavData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try transcribeWavBytes(
                        apiKey: apiKey,
                        wavBytes: wavData.bytes,
                        language: language
                    )
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: TranscriptionError.apiError(error.localizedDescription))
                }
            }
        }
    }
}
```

**新文件**: `Data/UseCases/PolishTextUseCase.swift`

```swift
import Foundation

final class PolishTextUseCase: PolishTextUseCaseProtocol {
    func execute(rawText: String, apiKey: String, context: String?) async throws -> String {
        guard !rawText.isEmpty else {
            throw PolishingError.emptyInput
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let polished = try polishText(
                        apiKey: apiKey,
                        rawText: rawText,
                        context: context
                    )
                    continuation.resume(returning: polished)
                } catch {
                    continuation.resume(throwing: PolishingError.apiError(error.localizedDescription))
                }
            }
        }
    }
}
```

**新文件**: `Data/UseCases/RecordingControlUseCase.swift`

```swift
import Foundation

final class RecordingControlUseCase: RecordingControlUseCaseProtocol {
    func startRecording() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try DIYTypeless.startRecording()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func warmupConnections() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                _ = try? warmupGroqConnection()
                _ = try? warmupGeminiConnection()
                continuation.resume()
            }
        }
    }
}
```

### 2.2 删除旧文件

删除 `Domain/UseCases/TranscriptionPipelineUseCase.swift`（内容已拆分）

---

## Phase 3: Presentation 层变更

### 3.1 修改 RecordingState

**文件**: `State/RecordingState.swift`

```swift
@MainActor
@Observable
final class RecordingState {
    private(set) var capsuleState: CapsuleState = .hidden

    var onRequireOnboarding: (() -> Void)?
    var onWillDeliverText: (() -> Void)?

    // Repositories
    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private var keyMonitoringRepository: KeyMonitoringRepository
    private let textOutputRepository: TextOutputRepository
    private let appContextRepository: AppContextRepository

    // UseCases - Recording Control
    private let recordingControlUseCase: RecordingControlUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol

    // UseCases - Transcription Pipeline
    private let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    private let polishTextUseCase: PolishTextUseCaseProtocol

    // UseCases - Voice Command
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol

    private var groqKey: String = ""
    private var geminiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    private var currentGeneration: Int = 0

    init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        keyMonitoringRepository: KeyMonitoringRepository,
        textOutputRepository: TextOutputRepository,
        appContextRepository: AppContextRepository = DefaultAppContextRepository(),
        // Recording control
        recordingControlUseCase: RecordingControlUseCaseProtocol = RecordingControlUseCase(),
        stopRecordingUseCase: StopRecordingUseCaseProtocol = StopRecordingUseCase(),
        // Transcription pipeline
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCase(),
        polishTextUseCase: PolishTextUseCaseProtocol = PolishTextUseCase(),
        // Voice command
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol = GetSelectedTextUseCase(),
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol = ProcessVoiceCommandUseCase()
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.keyMonitoringRepository = keyMonitoringRepository
        self.textOutputRepository = textOutputRepository
        self.appContextRepository = appContextRepository

        self.recordingControlUseCase = recordingControlUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.polishTextUseCase = polishTextUseCase
        self.getSelectedTextUseCase = getSelectedTextUseCase
        self.processVoiceCommandUseCase = processVoiceCommandUseCase

        setupKeyMonitoring()
    }

    private func setupKeyMonitoring() {
        keyMonitoringRepository.onFnDown = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyDown()
            }
        }
        keyMonitoringRepository.onFnUp = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyUp()
            }
        }
    }

    // ... activate(), deactivate(), handleCancel(), handleKeyDown() 保持不变 ...

    private func handleKeyUp() async {
        guard isRecording else { return }
        guard !isProcessing else { return }

        isRecording = false
        isProcessing = true
        currentGeneration += 1
        let gen = currentGeneration

        do {
            // Step 1: Stop recording and get audio data
            let selectedTextContext = await getSelectedTextUseCase.execute()
            let wavData = try await stopRecordingUseCase.execute()

            guard currentGeneration == gen else { return }

            // Step 2: Transcribe audio
            capsuleState = .transcribing(progress: 0)
            let rawText = try await transcribeAudioUseCase.execute(
                wavData: wavData,
                apiKey: groqKey,
                language: nil
            )

            guard currentGeneration == gen else { return }

            // Step 3: Determine processing mode
            if shouldUseVoiceCommandMode(selectedTextContext) {
                // Voice Command Mode
                try await handleVoiceCommandMode(
                    transcription: rawText,
                    selectedText: selectedTextContext.text!,
                    geminiKey: geminiKey,
                    generation: gen
                )
            } else {
                // Transcription Mode
                try await handleTranscriptionMode(
                    rawText: rawText,
                    geminiKey: geminiKey,
                    generation: gen
                )
            }

        } catch {
            guard currentGeneration == gen else { return }
            showError(error.localizedDescription)
            isProcessing = false
        }
    }

    private func handleVoiceCommandMode(
        transcription: String,
        selectedText: String,
        geminiKey: String,
        generation: Int
    ) async throws {
        capsuleState = .processingCommand(transcription, progress: 0)

        let result = try await processVoiceCommandUseCase.execute(
            transcription: transcription,
            selectedText: selectedText,
            geminiKey: geminiKey
        )

        guard currentGeneration == generation else { return }

        onWillDeliverText?()
        let outputResult = textOutputRepository.deliver(text: result.processedText)

        capsuleState = .done(outputResult)
        isProcessing = false

        scheduleHide(after: 1.2, expectedState: .done(outputResult))
    }

    private func handleTranscriptionMode(
        rawText: String,
        geminiKey: String,
        generation: Int
    ) async throws {
        // Step 3: Polish text
        capsuleState = .polishing(progress: 0)

        let polishedText = try await polishTextUseCase.execute(
            rawText: rawText,
            apiKey: geminiKey,
            context: capturedContext
        )

        guard currentGeneration == generation else { return }

        onWillDeliverText?()
        let outputResult = textOutputRepository.deliver(text: polishedText)

        capsuleState = .done(outputResult)
        isProcessing = false

        scheduleHide(after: 1.2, expectedState: .done(outputResult))
    }

    // ... 其他方法保持不变 ...
}
```

### 3.2 修改 CapsuleState 枚举

**文件**: `State/RecordingState.swift` 中的 `CapsuleState` 定义

```swift
enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing(progress: Double)      // 新增进度参数
    case polishing(progress: Double)         // 新增进度参数
    case processingCommand(String, progress: Double)  // 新增进度参数
    case done(OutputResult)
    case error(String)
}
```

### 3.3 修改 CapsuleView

**文件**: `Capsule/CapsuleView.swift`

```swift
struct CapsuleView: View {
    let state: RecordingState
    private let audioMonitor: AudioLevelProviding
    @State private var progress: CGFloat = 0

    init(state: RecordingState, audioMonitor: AudioLevelProviding = AudioLevelMonitor()) {
        self.state = state
        self.audioMonitor = audioMonitor
    }

    private let capsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36

    var body: some View {
        ZStack {
            // Background
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.18),
                            Color(white: 0.12),
                            Color(white: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                .padding(0.5)

            // Progress overlay for all processing states
            if shouldShowProgress {
                progressOverlay
            }

            content
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .onChange(of: state.capsuleState) { _, newState in
            handleStateChange(newState)
        }
    }

    private var shouldShowProgress: Bool {
        switch state.capsuleState {
        case .transcribing, .polishing, .processingCommand:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.capsuleState {
        case .recording:
            WaveformView(audioProvider: audioMonitor)
                .frame(width: capsuleWidth - 32)

        case .transcribing:
            Text("Transcribing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .polishing:
            Text("Polishing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .processingCommand:
            Text("Processing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .done(let result):
            Text(result == .pasted ? "Pasted" : "Copied")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(1)

        case .hidden:
            EmptyView()
        }
    }

    private var progressOverlay: some View {
        GeometryReader { geo in
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: geo.size.width * progress)
        }
        .clipShape(Capsule(style: .continuous))
    }

    private func handleStateChange(_ newState: CapsuleState) {
        switch newState {
        case .recording:
            audioMonitor.start()
            progress = 0

        case .transcribing:
            audioMonitor.stop()
            startProgressAnimation(duration: 2.5)

        case .polishing, .processingCommand:
            startProgressAnimation(duration: 2.0)

        case .done, .error:
            audioMonitor.stop()
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 1.0
            }

        case .hidden:
            audioMonitor.stop()
            progress = 0
        }
    }

    private func startProgressAnimation(duration: Double) {
        progress = 0
        withAnimation(.easeInOut(duration: duration)) {
            progress = 0.85
        }
    }
}
```

---

## Phase 4: 测试策略

### 4.1 单元测试 - StopRecordingUseCase

**文件**: `Tests/Unit/StopRecordingUseCaseTests.swift`

```swift
import Testing
@testable import DIYTypeless

@Suite("StopRecordingUseCase Tests")
struct StopRecordingUseCaseTests {

    @Test("execute returns WavData when recording is active")
    func testExecuteSuccess() async throws {
        // Given: Mock repository with expected data
        let expectedData = WavData(bytes: Data([0x52, 0x49, 0x46, 0x46])) // RIFF header
        let mockRepository = MockStopRecordingRepository(result: .success(expectedData))
        let useCase = StopRecordingUseCase(repository: mockRepository)

        // When: Execute use case
        let result = try await useCase.execute()

        // Then: Verify result
        #expect(result.bytes == expectedData.bytes)
    }

    @Test("execute throws when not recording")
    func testExecuteNotRecording() async {
        // Given: Mock repository with not recording error
        let mockRepository = MockStopRecordingRepository(
            result: .failure(RecordingError.notRecording)
        )
        let useCase = StopRecordingUseCase(repository: mockRepository)

        // When/Then: Verify error is thrown
        await #expect(throws: RecordingError.notRecording) {
            try await useCase.execute()
        }
    }
}

// MARK: - Mock

final class MockStopRecordingRepository: StopRecordingRepository {
    private let result: Result<WavData, Error>

    init(result: Result<WavData, Error>) {
        self.result = result
    }

    func stop() async throws -> WavData {
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
```

### 4.2 单元测试 - TranscribeAudioUseCase

**文件**: `Tests/Unit/TranscribeAudioUseCaseTests.swift`

```swift
import Testing
@testable import DIYTypeless

@Suite("TranscribeAudioUseCase Tests")
struct TranscribeAudioUseCaseTests {

    @Test("execute returns transcribed text")
    func testExecuteSuccess() async throws {
        // Given
        let wavData = WavData(bytes: Data([0x00, 0x01, 0x02]))
        let expectedText = "Hello world"
        let mockRepository = MockTranscriptionRepository(result: .success(expectedText))
        let useCase = TranscribeAudioUseCase(repository: mockRepository)

        // When
        let result = try await useCase.execute(
            wavData: wavData,
            apiKey: "test-key",
            language: nil
        )

        // Then
        #expect(result == expectedText)
        #expect(mockRepository.receivedWavData?.bytes == wavData.bytes)
        #expect(mockRepository.receivedApiKey == "test-key")
    }

    @Test("execute throws for empty audio")
    func testExecuteEmptyAudio() async {
        // Given
        let emptyWavData = WavData(bytes: Data())
        let mockRepository = MockTranscriptionRepository(result: .success(""))
        let useCase = TranscribeAudioUseCase(repository: mockRepository)

        // When/Then
        await #expect(throws: TranscriptionError.emptyAudio) {
            try await useCase.execute(
                wavData: emptyWavData,
                apiKey: "test-key",
                language: nil
            )
        }
    }
}
```

### 4.3 单元测试 - PolishTextUseCase

**文件**: `Tests/Unit/PolishTextUseCaseTests.swift`

```swift
import Testing
@testable import DIYTypeless

@Suite("PolishTextUseCase Tests")
struct PolishTextUseCaseTests {

    @Test("execute returns polished text")
    func testExecuteSuccess() async throws {
        // Given
        let rawText = "um like hello world"
        let expectedPolished = "Hello world."
        let mockRepository = MockPolishingRepository(result: .success(expectedPolished))
        let useCase = PolishTextUseCase(repository: mockRepository)

        // When
        let result = try await useCase.execute(
            rawText: rawText,
            apiKey: "test-key",
            context: "Notes app"
        )

        // Then
        #expect(result == expectedPolished)
        #expect(mockRepository.receivedRawText == rawText)
        #expect(mockRepository.receivedContext == "Notes app")
    }

    @Test("execute throws for empty input")
    func testExecuteEmptyInput() async {
        let mockRepository = MockPolishingRepository(result: .success(""))
        let useCase = PolishTextUseCase(repository: mockRepository)

        await #expect(throws: PolishingError.emptyInput) {
            try await useCase.execute(
                rawText: "",
                apiKey: "test-key",
                context: nil
            )
        }
    }
}
```

### 4.4 集成测试 - RecordingState

**文件**: `Tests/Integration/RecordingStateFlowTests.swift`

```swift
import Testing
@testable import DIYTypeless

@Suite("RecordingState Flow Tests")
struct RecordingStateFlowTests {

    @Test("state transitions correctly through transcription flow")
    func testTranscriptionFlow() async throws {
        // Given: Mock all dependencies
        let mockStopUseCase = MockStopRecordingUseCase()
        let mockTranscribeUseCase = MockTranscribeAudioUseCase()
        let mockPolishUseCase = MockPolishTextUseCase()

        let state = RecordingState(
            permissionRepository: MockPermissionRepository(allGranted: true),
            apiKeyRepository: MockApiKeyRepository(groqKey: "g", geminiKey: "m"),
            keyMonitoringRepository: MockKeyMonitoringRepository(),
            textOutputRepository: MockTextOutputRepository(),
            stopRecordingUseCase: mockStopUseCase,
            transcribeAudioUseCase: mockTranscribeUseCase,
            polishTextUseCase: mockPolishUseCase
        )

        // When: Simulate key up
        await state.handleKeyUp()

        // Then: Verify state transitions
        // Initial: .transcribing
        // After transcribe: .polishing
        // After polish: .done

        // Verify each use case was called in order
        #expect(mockStopUseCase.executeCallCount == 1)
        #expect(mockTranscribeUseCase.executeCallCount == 1)
        #expect(mockPolishUseCase.executeCallCount == 1)
    }

    @Test("state transitions correctly through voice command flow")
    func testVoiceCommandFlow() async throws {
        // Given: Mock with selected text context
        let mockGetSelectedText = MockGetSelectedTextUseCase(
            context: SelectedTextContext(hasSelection: true, isEditable: true, isSecure: false, text: "selected")
        )
        let mockProcessCommand = MockProcessVoiceCommandUseCase()

        // ... similar test structure
    }
}
```

---

## Phase 5: 实施顺序

### 可以并行的任务

1. **Domain 层协议定义**（Phase 1）
   - 定义三个新 UseCase 协议
   - 重命名/清理旧文件

2. **CapsuleState 修改**（Phase 3.2）
   - 添加进度参数到相关 case

### 有依赖关系的任务

```
Phase 1: Domain 层协议定义
    ↓
Phase 2: Data 层实现
    ↓
Phase 3.1: RecordingState 重写
    ↓
Phase 3.3: CapsuleView 修复
    ↓
Phase 4: 测试编写
```

### 具体实施步骤

**Step 1**: 创建 Domain 层新文件
- `Domain/UseCases/StopRecordingUseCase.swift`
- `Domain/UseCases/TranscribeAudioUseCase.swift`
- `Domain/UseCases/PolishTextUseCase.swift`
- `Domain/UseCases/RecordingControlUseCase.swift`（提取）
- `Domain/UseCases/TranscriptionEntities.swift`（重命名）

**Step 2**: 创建 Data 层实现
- `Data/UseCases/StopRecordingUseCase.swift`
- `Data/UseCases/TranscribeAudioUseCase.swift`
- `Data/UseCases/PolishTextUseCase.swift`
- `Data/UseCases/RecordingControlUseCase.swift`

**Step 3**: 删除旧文件
- `Domain/UseCases/TranscriptionPipelineUseCase.swift`
- `Domain/UseCases/TranscriptionUseCase.swift`（如果已重命名）

**Step 4**: 修改 RecordingState
- 更新 init 参数
- 重写 handleKeyUp()
- 修改 handleTranscriptionMode() 和 handleVoiceCommandMode()

**Step 5**: 修改 CapsuleState 和 CapsuleView
- 添加进度参数
- 修复 progressOverlay 显示逻辑

**Step 6**: 运行构建验证
```bash
./scripts/dev-loop-build.sh --testing
```

**Step 7**: 编写测试
- 单元测试三个 UseCase
- 集成测试 RecordingState 状态流转

---

## 风险评估

### 低风险
- Domain 层协议定义：纯接口，无副作用
- Data 层实现：代码从旧文件迁移，逻辑不变

### 中风险
- RecordingState 重写：需要仔细验证状态流转逻辑
- 依赖注入修改：需要确保所有 init 调用点更新

### 缓解措施
1. 保留旧的 `TranscriptionPipelineUseCase` 直到新实现验证通过
2. 使用 Xcode 的 "Find Call Hierarchy" 检查所有 init 调用
3. 先实现一个 UseCase，验证通过后再实现其他两个

---

## 验收标准

1. [ ] 编译通过，无警告
2. [ ] 三个 UseCase 都有单元测试，覆盖率 > 80%
3. [ ] RecordingState 状态流转测试通过
4. [ ] 手动测试验证：
   - [ ] 普通转录模式：能看到 "Transcribing" -> "Polishing" -> "Pasted"
   - [ ] Voice command 模式：能看到 "Transcribing" -> "Processing" -> "Pasted"
   - [ ] 每个状态都有进度条动画
5. [ ] 取消操作正常工作
6. [ ] 错误处理正常工作
