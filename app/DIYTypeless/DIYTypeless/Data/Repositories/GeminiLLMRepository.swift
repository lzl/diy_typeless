import Foundation

/// Repository implementation that calls Gemini API via Rust FFI.
/// Wraps synchronous FFI calls in async continuations on background thread.
final class GeminiLLMRepository: LLMRepository {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processTextWithLLM(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: Float(temperature ?? 0.3)
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
