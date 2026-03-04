import Foundation

/// Repository protocol for validating API keys with provider servers.
protocol ApiKeyValidationRepository: Sendable {
    /// Validates an API key by making a test request to the provider's API.
    /// - Parameter key: The API key to validate
    /// - Throws: ValidationError if the key is invalid or request fails
    func validate(key: String) async throws
}
