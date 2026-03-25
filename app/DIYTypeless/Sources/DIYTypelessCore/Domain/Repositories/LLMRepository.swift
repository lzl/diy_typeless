import Foundation

/// Repository protocol for LLM text generation.
/// Following project convention, protocol names do not have "Protocol" suffix.
public protocol LLMRepository: Sendable {
    func generate(
        provider: ApiProvider,
        apiKey: String,
        prompt: String,
        temperature: Double?,
        cancellationToken: CancellationToken?
    ) async throws -> String
}
