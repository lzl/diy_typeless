import Foundation

/// Use case for processing voice commands with selected text.
/// Single Responsibility: Processes voice command and returns result.
/// Does not handle output delivery (paste/copy) - that is the caller's responsibility.
final class ProcessVoiceCommandUseCaseImpl: ProcessVoiceCommandUseCaseProtocol {
    private let llmRepository: LLMRepository

    init(llmRepository: LLMRepository = GeminiLLMRepository()) {
        self.llmRepository = llmRepository
    }

    func execute(
        transcription: String,
        selectedText: String,
        geminiKey: String
    ) async throws -> VoiceCommandResult {
        // Build prompt combining command and selected text
        let prompt = buildPrompt(command: transcription, selectedText: selectedText)

        do {
            // Call LLM
            let response = try await llmRepository.generate(
                apiKey: geminiKey,
                prompt: prompt,
                temperature: 0.3
            )

            // Return result with recommended action
            return VoiceCommandResult(
                processedText: response,
                action: .replaceSelection
            )
        } catch let coreError as CoreError {
            throw CoreErrorMapper.toUserFacingError(coreError)
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
