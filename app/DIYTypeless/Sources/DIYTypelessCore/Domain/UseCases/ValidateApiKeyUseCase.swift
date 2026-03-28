import Foundation

/// Protocol for validating API keys.
public protocol ValidateApiKeyUseCaseProtocol: Sendable {
    /// Validates an API key for the specified provider.
    /// - Parameters:
    ///   - key: The API key to validate
    ///   - provider: The API provider (groq or gemini)
    /// - Throws: ValidationError if validation fails
    func execute(key: String, for provider: ApiProvider) async throws
}

/// Use case for validating API keys.
/// This use case encapsulates the business logic of validating API keys
/// by delegating to the appropriate repository implementation.
public final class ValidateApiKeyUseCase: ValidateApiKeyUseCaseProtocol {
    private let groqRepository: ApiKeyValidationRepository
    private let geminiRepository: ApiKeyValidationRepository
    private let openAIRepository: ApiKeyValidationRepository

    public init(
        groqRepository: ApiKeyValidationRepository,
        geminiRepository: ApiKeyValidationRepository,
        openAIRepository: ApiKeyValidationRepository
    ) {
        self.groqRepository = groqRepository
        self.geminiRepository = geminiRepository
        self.openAIRepository = openAIRepository
    }

    public func execute(key: String, for provider: ApiProvider) async throws {
        switch provider {
        case .groq:
            try await groqRepository.validate(key: key)
        case .gemini:
            try await geminiRepository.validate(key: key)
        case .openai:
            try await openAIRepository.validate(key: key)
        }
    }
}
