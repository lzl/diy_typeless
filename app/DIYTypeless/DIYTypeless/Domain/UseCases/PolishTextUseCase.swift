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
