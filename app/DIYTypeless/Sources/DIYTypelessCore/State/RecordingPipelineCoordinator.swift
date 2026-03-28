import Foundation

public struct RecordingPipelineRequest: Sendable {
    public let groqKey: String
    public let llmProvider: ApiProvider
    public let llmApiKey: String
    public let selectedTextContext: SelectedTextContext
    public let appContext: String?
    public let cancellationToken: CancellationToken?

    public init(
        groqKey: String,
        llmProvider: ApiProvider,
        llmApiKey: String,
        selectedTextContext: SelectedTextContext,
        appContext: String?,
        cancellationToken: CancellationToken?
    ) {
        self.groqKey = groqKey
        self.llmProvider = llmProvider
        self.llmApiKey = llmApiKey
        self.selectedTextContext = selectedTextContext
        self.appContext = appContext
        self.cancellationToken = cancellationToken
    }
}

public enum RecordingPipelineProgress: Equatable, Sendable {
    case recordingStopped
    case transcribing
    case polishing
    case processingCommand(String)
}

public enum RecordingPipelineResult: Sendable {
    case polishedText(String)
    case voiceCommand(VoiceCommandResult)
}

public protocol RecordingPipelineCoordinating {
    func execute(
        request: RecordingPipelineRequest,
        onProgress: @escaping (RecordingPipelineProgress) async -> Void
    ) async throws -> RecordingPipelineResult

    func mapToUserFacingError(_ error: Error) -> UserFacingError?
}

public final class RecordingPipelineCoordinator: RecordingPipelineCoordinating {
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    private let polishTextUseCase: PolishTextUseCaseProtocol
    private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol

    public init(
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol,
        polishTextUseCase: PolishTextUseCaseProtocol,
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol
    ) {
        self.stopRecordingUseCase = stopRecordingUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.polishTextUseCase = polishTextUseCase
        self.processVoiceCommandUseCase = processVoiceCommandUseCase
    }

    public func execute(
        request: RecordingPipelineRequest,
        onProgress: @escaping (RecordingPipelineProgress) async -> Void
    ) async throws -> RecordingPipelineResult {
        let audio = try await stopRecordingUseCase.execute()

        await onProgress(.recordingStopped)
        await onProgress(.transcribing)
        let rawText = try await transcribeAudioUseCase.execute(
            audioData: audio,
            apiKey: request.groqKey,
            language: nil,
            cancellationToken: request.cancellationToken
        )

        if request.selectedTextContext.hasSelection,
           !request.selectedTextContext.isSecure,
           let selectedText = request.selectedTextContext.text {
            await onProgress(.processingCommand(rawText))
            let result = try await processVoiceCommandUseCase.execute(
                transcription: rawText,
                selectedText: selectedText,
                provider: request.llmProvider,
                apiKey: request.llmApiKey,
                cancellationToken: request.cancellationToken
            )
            return .voiceCommand(result)
        }

        await onProgress(.polishing)
        let polishedText = try await polishTextUseCase.execute(
            rawText: rawText,
            provider: request.llmProvider,
            apiKey: request.llmApiKey,
            context: request.appContext,
            cancellationToken: request.cancellationToken
        )
        return .polishedText(polishedText)
    }

    public func mapToUserFacingError(_ error: Error) -> UserFacingError? {
        if error is CancellationError {
            return nil
        }
        if let error = error as? TranscriptionError {
            switch error {
            case .apiError(let userError):
                return userError
            case .emptyAudio, .decodingFailed:
                return .unknown("Transcription failed")
            }
        }
        if let error = error as? PolishingError {
            switch error {
            case .apiError(let userError):
                return userError
            case .emptyInput, .invalidResponse:
                return .unknown("Polishing failed")
            }
        }
        if let error = error as? UserFacingError {
            return error
        }
        return .unknown(error.localizedDescription)
    }
}
