import Foundation

/// Protocol for transcribing audio to text
protocol TranscribeAudioUseCaseProtocol: Sendable {
    /// Transcribes audio data to raw text
    /// - Parameters:
    ///   - audioData: The audio data to transcribe (FLAC format)
    ///   - apiKey: Groq API key
    ///   - language: Optional language hint (e.g., "zh", "en")
    ///   - cancellationToken: Optional cooperative cancellation token
    /// - Returns: Raw transcribed text
    /// - Throws: TranscriptionError if transcription fails
    func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CoreCancellationToken?
    ) async throws -> String
}

enum TranscriptionError: Error, Equatable {
    case emptyAudio
    case cancelled
    case apiError(UserFacingError)
    case decodingFailed
}
