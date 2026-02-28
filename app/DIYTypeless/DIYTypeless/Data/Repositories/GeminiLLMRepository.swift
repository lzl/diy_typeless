import Foundation

/// Repository implementation that calls Gemini API via Rust FFI.
/// Wraps synchronous FFI calls in async continuations on background thread.
///
/// Note: This repository throws CoreError directly. Error mapping to UserFacingError
/// should be handled by the UseCase layer to maintain proper dependency boundaries.
final class GeminiLLMRepository: LLMRepository {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processTextWithLlm(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: Float(temperature ?? 0.3)
                    )
                    continuation.resume(returning: result)
                } catch let coreError as CoreError {
                    // Pass through CoreError directly - UseCase will map to UserFacingError
                    continuation.resume(throwing: coreError)
                } catch {
                    // Wrap unknown errors in CoreError.Api
                    continuation.resume(throwing: CoreError.Api(error.localizedDescription))
                }
            }
        }
    }

}
