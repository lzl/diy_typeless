import Foundation

/// Use case for processing voice commands with selected text.
/// Single Responsibility: Processes voice command and returns result.
/// Does not handle output delivery (paste/copy) - that is the caller's responsibility.
public final class ProcessVoiceCommandUseCaseImpl: ProcessVoiceCommandUseCaseProtocol {
    private let llmRepository: LLMRepository

    public init(llmRepository: LLMRepository) {
        self.llmRepository = llmRepository
    }

    public func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String,
        cancellationToken: CancellationToken?
    ) async throws -> VoiceCommandResult {
        if cancellationToken?.isCancelled() == true {
            throw CancellationError()
        }
        try Task.checkCancellation()

        // Build prompt combining command and selected text
        let prompt = buildPrompt(command: transcription, selectedText: selectedText)

        do {
            // Call LLM
            let response = try await llmRepository.generate(
                apiKey: geminiKey,
                prompt: prompt,
                temperature: 0.3,
                cancellationToken: cancellationToken
            )

            // Return result with recommended action
            return VoiceCommandResult(
                processedText: response,
                action: .replaceSelection
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let coreError as CoreError {
            switch coreError {
            case .Cancelled:
                throw CancellationError()
            case .Api(let message):
                throw CoreErrorMapper.toUserFacingError(category: .api, message: message)
            case .Http(let message):
                throw CoreErrorMapper.toUserFacingError(category: .network, message: message)
            default:
                throw CoreErrorMapper.toUserFacingError(
                    category: .unknown,
                    message: coreError.localizedDescription
                )
            }
        } catch {
            throw UserFacingError.unknown(error.localizedDescription)
        }
    }

    private func buildPrompt(command: String, selectedText: String) -> String {
        """
        User has selected the following text:
        '''
        \(selectedText)
        '''

        User says: \(command)

        Please understand the user's intent and perform the appropriate operation on the selected text.
        Only return the processed text, no explanations, no quotes.
        """
    }
}
