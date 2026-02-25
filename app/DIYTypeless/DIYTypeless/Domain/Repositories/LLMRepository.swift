import Foundation

/// Repository protocol for LLM text generation.
/// Following project convention, protocol names do not have "Protocol" suffix.
protocol LLMRepository: Sendable {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String
}
