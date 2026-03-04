import Foundation

/// Protocol for ProcessVoiceCommandUseCase.
public protocol ProcessVoiceCommandUseCaseProtocol: Sendable {
    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String,
        cancellationToken: CancellationToken?
    ) async throws -> VoiceCommandResult
}
