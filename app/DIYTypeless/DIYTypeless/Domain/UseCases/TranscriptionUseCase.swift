import Foundation

/// Protocol for the complete transcription pipeline
/// This is a facade that composes the individual use cases
protocol TranscriptionUseCaseProtocol: Sendable {
    /// Executes the complete transcription pipeline
    /// - Parameters:
    ///   - groqKey: Groq API key for transcription
    ///   - geminiKey: Gemini API key for text polishing
    ///   - context: Optional context about the active application
    /// - Returns: TranscriptionResult containing raw and polished text
    /// - Throws: RecordingError, TranscriptionError, or PolishingError
    func execute(groqKey: String, geminiKey: String, context: String?) async throws -> TranscriptionResult
}

/// Facade use case that composes the individual transcription steps
/// This maintains backward compatibility while using the new granular use cases internally
final class TranscriptionUseCase: TranscriptionUseCaseProtocol {
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    private let polishTextUseCase: PolishTextUseCaseProtocol

    init(
        stopRecordingUseCase: StopRecordingUseCaseProtocol = StopRecordingUseCaseImpl(),
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCaseImpl(),
        polishTextUseCase: PolishTextUseCaseProtocol = PolishTextUseCaseImpl()
    ) {
        self.stopRecordingUseCase = stopRecordingUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.polishTextUseCase = polishTextUseCase
    }

    func execute(groqKey: String, geminiKey: String, context: String?) async throws -> TranscriptionResult {
        // Step 1: Stop recording and get audio data
        let audioData = try await stopRecordingUseCase.execute()

        // Step 2: Transcribe audio
        let rawText = try await transcribeAudioUseCase.execute(
            audioData: audioData,
            apiKey: groqKey,
            language: nil
        )

        // Step 3: Polish text
        let polishedText = try await polishTextUseCase.execute(
            rawText: rawText,
            apiKey: geminiKey,
            context: context
        )

        // Step 4: Return result (output delivery handled by caller)
        return TranscriptionResult(
            rawText: rawText,
            polishedText: polishedText,
            outputResult: .pasted
        )
    }
}
