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
