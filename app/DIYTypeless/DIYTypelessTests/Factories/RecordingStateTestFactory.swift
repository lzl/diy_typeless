import Foundation
@testable import DIYTypeless

/// Factory for creating RecordingState instances for testing.
/// Provides sensible defaults for all dependencies with mock implementations.
@MainActor
final class RecordingStateTestFactory {

    // MARK: - Default Mocks

    static func makePermissionRepository() -> PermissionRepository {
        MockPermissionRepository()
    }

    static func makeApiKeyRepository() -> ApiKeyRepository {
        MockApiKeyRepository()
    }

    static func makeKeyMonitoringRepository() -> KeyMonitoringRepository {
        MockKeyMonitoringRepository()
    }

    static func makeTextOutputRepository() -> TextOutputRepository {
        MockTextOutputRepository()
    }

    static func makeAppContextRepository() -> AppContextRepository {
        MockAppContextRepository()
    }

    static func makeRecordingControlUseCase() -> RecordingControlUseCaseProtocol {
        MockRecordingControlUseCase()
    }

    static func makeStopRecordingUseCase() -> StopRecordingUseCaseProtocol {
        MockStopRecordingUseCase()
    }

    static func makeTranscribeAudioUseCase() -> TranscribeAudioUseCaseProtocol {
        MockTranscribeAudioUseCase()
    }

    static func makePolishTextUseCase() -> PolishTextUseCaseProtocol {
        MockPolishTextUseCase()
    }

    static func makeGetSelectedTextUseCase() -> GetSelectedTextUseCaseProtocol {
        MockGetSelectedTextUseCase()
    }

    static func makeProcessVoiceCommandUseCase() -> ProcessVoiceCommandUseCaseProtocol {
        MockProcessVoiceCommandUseCase()
    }

    // MARK: - Factory Method

    /// Creates a RecordingState with minimal configuration.
    /// - Parameters:
    ///   - permissionRepository: Optional custom permission repository (default: mock)
    ///   - apiKeyRepository: Optional custom API key repository (default: mock)
    ///   - keyMonitoringRepository: Optional custom key monitoring repository (default: mock)
    ///   - textOutputRepository: Optional custom text output repository (default: mock)
    ///   - appContextRepository: Optional custom app context repository (default: mock)
    ///   - recordingControlUseCase: Optional custom recording control use case (default: mock)
    ///   - stopRecordingUseCase: Optional custom stop recording use case (default: mock)
    ///   - transcribeAudioUseCase: Optional custom transcribe audio use case (default: mock)
    ///   - polishTextUseCase: Optional custom polish text use case (default: mock)
    ///   - getSelectedTextUseCase: Optional custom get selected text use case (default: mock)
    ///   - processVoiceCommandUseCase: Optional custom process voice command use case (default: mock)
    /// - Returns: Configured RecordingState instance
    static func makeRecordingState(
        permissionRepository: PermissionRepository? = nil,
        apiKeyRepository: ApiKeyRepository? = nil,
        keyMonitoringRepository: KeyMonitoringRepository? = nil,
        textOutputRepository: TextOutputRepository? = nil,
        appContextRepository: AppContextRepository? = nil,
        recordingControlUseCase: RecordingControlUseCaseProtocol? = nil,
        stopRecordingUseCase: StopRecordingUseCaseProtocol? = nil,
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol? = nil,
        polishTextUseCase: PolishTextUseCaseProtocol? = nil,
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol? = nil,
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol? = nil
    ) -> RecordingState {
        RecordingState(
            permissionRepository: permissionRepository ?? makePermissionRepository(),
            apiKeyRepository: apiKeyRepository ?? makeApiKeyRepository(),
            keyMonitoringRepository: keyMonitoringRepository ?? makeKeyMonitoringRepository(),
            textOutputRepository: textOutputRepository ?? makeTextOutputRepository(),
            appContextRepository: appContextRepository ?? makeAppContextRepository(),
            recordingControlUseCase: recordingControlUseCase ?? makeRecordingControlUseCase(),
            stopRecordingUseCase: stopRecordingUseCase ?? makeStopRecordingUseCase(),
            transcribeAudioUseCase: transcribeAudioUseCase ?? makeTranscribeAudioUseCase(),
            polishTextUseCase: polishTextUseCase ?? makePolishTextUseCase(),
            getSelectedTextUseCase: getSelectedTextUseCase ?? makeGetSelectedTextUseCase(),
            processVoiceCommandUseCase: processVoiceCommandUseCase ?? makeProcessVoiceCommandUseCase()
        )
    }
}

// MARK: - Mock Repositories

/// Mock PermissionRepository
@MainActor
final class MockPermissionRepository: PermissionRepository {
    var currentStatus: PermissionStatus = PermissionStatus(accessibility: true, microphone: true)

    func requestAccessibility() -> Bool { true }
    func requestMicrophone() async -> Bool { true }
    func openAccessibilitySettings() {}
    func openMicrophoneSettings() {}
}

/// Mock ApiKeyRepository
@MainActor
final class MockApiKeyRepository: ApiKeyRepository {
    private var keys: [ApiProvider: String] = [
        .groq: "test-groq-key",
        .gemini: "test-gemini-key"
    ]

    func loadKey(for provider: ApiProvider) -> String? {
        keys[provider]
    }

    func saveKey(_ key: String, for provider: ApiProvider) throws {
        keys[provider] = key
    }

    func deleteKey(for provider: ApiProvider) throws {
        keys[provider] = nil
    }
}

/// Mock KeyMonitoringRepository
@MainActor
final class MockKeyMonitoringRepository: KeyMonitoringRepository {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var isRunning = false

    func start() -> Bool {
        isRunning = true
        return true
    }

    func stop() {
        isRunning = false
    }
}

/// Mock TextOutputRepository
@MainActor
final class MockTextOutputRepository: TextOutputRepository {
    var lastDeliveredText: String?
    var lastResult: OutputResult = .pasted

    func deliver(text: String) -> OutputResult {
        lastDeliveredText = text
        return lastResult
    }
}

/// Mock AppContextRepository
@MainActor
final class MockAppContextRepository: AppContextRepository {
    var capturedContext: AppContext = AppContext(
        appName: "TestApp",
        bundleIdentifier: "com.test.app",
        url: nil
    )

    func captureContext() -> AppContext {
        capturedContext
    }
}

// MARK: - Mock UseCases

/// Mock RecordingControlUseCase
@MainActor
final class MockRecordingControlUseCase: RecordingControlUseCaseProtocol {
    var startRecordingCalled = false
    var warmupConnectionsCalled = false

    func startRecording() async throws {
        startRecordingCalled = true
    }

    func warmupConnections() async {
        warmupConnectionsCalled = true
    }
}

/// MockTranscribeAudioUseCase
@MainActor
final class MockTranscribeAudioUseCase: TranscribeAudioUseCaseProtocol {
    var returnValue: String = "transcribed text"
    var errorToThrow: TranscriptionError?

    func execute(audioData: AudioData, apiKey: String, language: String?) async throws -> String {
        if let error = errorToThrow {
            throw error
        }
        return returnValue
    }
}

/// MockPolishTextUseCase
@MainActor
final class MockPolishTextUseCase: PolishTextUseCaseProtocol {
    var returnValue: String = "polished text"
    var errorToThrow: PolishingError?
    private(set) var executeCount = 0

    func execute(rawText: String, apiKey: String, context: String?) async throws -> String {
        executeCount += 1
        if let error = errorToThrow {
            throw error
        }
        return returnValue
    }
}

/// MockProcessVoiceCommandUseCase
@MainActor
final class MockProcessVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol {
    var returnValue: VoiceCommandResult = VoiceCommandResult(
        processedText: "processed text",
        action: .replaceSelection
    )
    var errorToThrow: Error?
    private(set) var executeCount = 0

    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult {
        executeCount += 1
        if let error = errorToThrow {
            throw error
        }
        return returnValue
    }
}
