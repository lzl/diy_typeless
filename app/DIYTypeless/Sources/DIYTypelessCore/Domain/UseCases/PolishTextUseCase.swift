import Foundation

/// Protocol for polishing transcribed text
public protocol PolishTextUseCaseProtocol: Sendable {
    /// Polishes raw transcribed text using LLM
    /// - Parameters:
    ///   - rawText: The raw text from transcription
    ///   - apiKey: Gemini API key
    ///   - context: Optional context about the active application
    ///   - cancellationToken: Optional cancellation token for cooperative cancellation
    /// - Returns: Polished text
    /// - Throws: PolishingError if polishing fails
    func execute(
        rawText: String,
        apiKey: String,
        context: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String
}

public enum PolishingError: Error, Equatable {
    case emptyInput
    case apiError(UserFacingError)
    case invalidResponse
}
