import Foundation
import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

@MainActor
extension XCTestCase {
    func waitUntil(
        timeout: TimeInterval = 1.0,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}

final class FakeCancellationToken: CancellationToken, @unchecked Sendable {
    private var cancelled: Bool

    init(isCancelled: Bool = false) {
        self.cancelled = isCancelled
        super.init(noHandle: CancellationToken.NoHandle())
    }

    nonisolated required init(unsafeFromHandle handle: UInt64) {
        fatalError("unsafeFromHandle is unsupported in tests")
    }

    nonisolated override func cancel() {
        cancelled = true
    }

    nonisolated override func isCancelled() -> Bool {
        cancelled
    }
}

final class MockPermissionRepository: PermissionRepository, @unchecked Sendable {
    var currentStatus: PermissionStatus
    var requestAccessibilityResult = true
    var requestMicrophoneResult = true

    private(set) var requestAccessibilityCallCount = 0
    private(set) var requestMicrophoneCallCount = 0
    private(set) var openAccessibilitySettingsCallCount = 0
    private(set) var openMicrophoneSettingsCallCount = 0

    init(currentStatus: PermissionStatus = PermissionStatus(accessibility: true, microphone: true)) {
        self.currentStatus = currentStatus
    }

    func requestAccessibility() -> Bool {
        requestAccessibilityCallCount += 1
        return requestAccessibilityResult
    }

    func requestMicrophone() async -> Bool {
        requestMicrophoneCallCount += 1
        return requestMicrophoneResult
    }

    func openAccessibilitySettings() {
        openAccessibilitySettingsCallCount += 1
    }

    func openMicrophoneSettings() {
        openMicrophoneSettingsCallCount += 1
    }
}

final class MockApiKeyRepository: ApiKeyRepository, @unchecked Sendable {
    var keys: [ApiProvider: String] = [:]
    var saveError: Error?
    var deleteError: Error?

    private(set) var saveCalls: [(provider: ApiProvider, key: String)] = []
    private(set) var deleteCalls: [ApiProvider] = []

    func loadKey(for provider: ApiProvider) -> String? {
        keys[provider]
    }

    func saveKey(_ key: String, for provider: ApiProvider) throws {
        if let saveError {
            throw saveError
        }
        keys[provider] = key
        saveCalls.append((provider: provider, key: key))
    }

    func deleteKey(for provider: ApiProvider) throws {
        if let deleteError {
            throw deleteError
        }
        keys.removeValue(forKey: provider)
        deleteCalls.append(provider)
    }
}

final class MockKeyMonitoringRepository: KeyMonitoringRepository, @unchecked Sendable {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    var startResult = true

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() -> Bool {
        startCallCount += 1
        return startResult
    }

    func stop() {
        stopCallCount += 1
    }

    func triggerFnDown() {
        onFnDown?()
    }

    func triggerFnUp() {
        onFnUp?()
    }
}

final class MockTextOutputRepository: TextOutputRepository, @unchecked Sendable {
    var deliverResult: OutputResult = .pasted

    private(set) var deliverCalls: [String] = []
    private(set) var copiedTexts: [String] = []

    func deliver(text: String) -> OutputResult {
        deliverCalls.append(text)
        return deliverResult
    }

    func copyToClipboard(text: String) {
        copiedTexts.append(text)
    }
}

final class MockAppContextRepository: AppContextRepository, @unchecked Sendable {
    var context: AppContext
    private(set) var captureCallCount = 0

    init(context: AppContext = AppContext(appName: "TestApp", bundleIdentifier: "com.test.app", url: "https://example.com")) {
        self.context = context
    }

    func captureContext() -> AppContext {
        captureCallCount += 1
        return context
    }
}

final class MockRecordingControlUseCase: RecordingControlUseCaseProtocol, @unchecked Sendable {
    var startRecordingError: Error?
    private(set) var startRecordingCallCount = 0
    private(set) var warmupCallCount = 0

    func startRecording() async throws {
        startRecordingCallCount += 1
        if let startRecordingError {
            throw startRecordingError
        }
    }

    func warmupConnections() async {
        warmupCallCount += 1
    }
}

final class MockStopRecordingUseCase: StopRecordingUseCaseProtocol, @unchecked Sendable {
    var result = DomainAudioData(bytes: Data([1, 2, 3]), durationSeconds: 0.5)
    var error: Error?
    var beforeReturnDelayNanoseconds: UInt64 = 0

    private(set) var executeCallCount = 0
    private(set) var completedCallCount = 0

    func execute() async throws -> DomainAudioData {
        executeCallCount += 1
        if beforeReturnDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: beforeReturnDelayNanoseconds)
        }
        if let error {
            throw error
        }
        completedCallCount += 1
        return result
    }
}

final class MockTranscribeAudioUseCase: TranscribeAudioUseCaseProtocol, @unchecked Sendable {
    var result = "raw transcript"
    var error: Error?
    var beforeReturnDelayNanoseconds: UInt64 = 0

    private(set) var executeCallCount = 0
    private(set) var receivedAudio: DomainAudioData?
    private(set) var receivedAPIKey: String?
    private(set) var receivedCancellationToken: CancellationToken?

    func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        executeCallCount += 1
        receivedAudio = audioData
        receivedAPIKey = apiKey
        receivedCancellationToken = cancellationToken

        if beforeReturnDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: beforeReturnDelayNanoseconds)
        }

        if cancellationToken?.isCancelled() == true {
            throw CancellationError()
        }

        if let error {
            throw error
        }
        return result
    }
}

final class MockPolishTextUseCase: PolishTextUseCaseProtocol, @unchecked Sendable {
    var result = "polished"
    var error: Error?

    private(set) var executeCallCount = 0
    private(set) var receivedRawText: String?
    private(set) var receivedAPIKey: String?
    private(set) var receivedContext: String?

    func execute(
        rawText: String,
        apiKey: String,
        context: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        executeCallCount += 1
        receivedRawText = rawText
        receivedAPIKey = apiKey
        receivedContext = context

        if cancellationToken?.isCancelled() == true {
            throw CancellationError()
        }

        if let error {
            throw error
        }
        return result
    }
}

final class MockGetSelectedTextUseCase: GetSelectedTextUseCaseProtocol, @unchecked Sendable {
    var result: SelectedTextContext = .empty
    private(set) var executeCallCount = 0

    func execute() async -> SelectedTextContext {
        executeCallCount += 1
        return result
    }
}

final class MockProcessVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol, @unchecked Sendable {
    var result = VoiceCommandResult(processedText: "processed", action: .replaceSelection)
    var error: Error?

    private(set) var executeCallCount = 0
    private(set) var receivedTranscription: String?
    private(set) var receivedSelectedText: String?
    private(set) var receivedGeminiKey: String?

    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String,
        cancellationToken: CancellationToken?
    ) async throws -> VoiceCommandResult {
        executeCallCount += 1
        receivedTranscription = transcription
        receivedSelectedText = selectedText
        receivedGeminiKey = geminiKey

        if cancellationToken?.isCancelled() == true {
            throw CancellationError()
        }

        if let error {
            throw error
        }
        return result
    }
}

final class MockPrefetchScheduler: PrefetchScheduler, @unchecked Sendable {
    var shouldRunImmediately = true

    private(set) var scheduleCallCount = 0
    private(set) var cancelCallCount = 0
    private var scheduledOperations: [@Sendable () async -> Void] = []

    func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        scheduleCallCount += 1
        if shouldRunImmediately {
            return Task {
                await operation()
            }
        }

        scheduledOperations.append(operation)
        return Task {}
    }

    func cancel(_ task: Task<Void, Never>) {
        cancelCallCount += 1
        task.cancel()
    }

    func runScheduledOperations() async {
        let operations = scheduledOperations
        scheduledOperations.removeAll()
        for operation in operations {
            await operation()
        }
    }
}

final class MockExternalLinkRepository: ExternalLinkRepository, @unchecked Sendable {
    private(set) var openedProviders: [ApiProvider] = []

    func openConsole(for provider: ApiProvider) {
        openedProviders.append(provider)
    }
}

final class MockValidateApiKeyUseCase: ValidateApiKeyUseCaseProtocol, @unchecked Sendable {
    enum Behavior {
        case success
        case failure(Error)
    }

    var behaviorByProvider: [ApiProvider: Behavior] = [.groq: .success, .gemini: .success]
    private(set) var executeCalls: [(provider: ApiProvider, key: String)] = []

    func execute(key: String, for provider: ApiProvider) async throws {
        executeCalls.append((provider: provider, key: key))
        if case .failure(let error) = behaviorByProvider[provider] ?? .success {
            throw error
        }
    }
}

final class MockLLMRepository: LLMRepository, @unchecked Sendable {
    var response = "ok"
    var error: Error?

    private(set) var generateCallCount = 0
    private(set) var receivedAPIKey: String?
    private(set) var receivedPrompt: String?
    private(set) var receivedTemperature: Double?

    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        generateCallCount += 1
        receivedAPIKey = apiKey
        receivedPrompt = prompt
        receivedTemperature = temperature

        if cancellationToken?.isCancelled() == true {
            throw CancellationError()
        }

        if let error {
            throw error
        }

        return response
    }
}
