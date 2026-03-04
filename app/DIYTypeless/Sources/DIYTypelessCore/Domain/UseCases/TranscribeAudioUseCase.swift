import Foundation

/// Protocol for transcribing audio to text
protocol TranscribeAudioUseCaseProtocol: Sendable {
    /// Transcribes audio data to raw text
    /// - Parameters:
    ///   - audioData: The audio data to transcribe (FLAC format)
    ///   - apiKey: Groq API key
    ///   - language: Optional language hint (e.g., "zh", "en")
    ///   - cancellationToken: Optional cancellation token for cooperative cancellation
    /// - Returns: Raw transcribed text
    /// - Throws: TranscriptionError if transcription fails
    func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String
}

enum TranscriptionError: Error, Equatable {
    case emptyAudio
    case apiError(UserFacingError)
    case decodingFailed
}
