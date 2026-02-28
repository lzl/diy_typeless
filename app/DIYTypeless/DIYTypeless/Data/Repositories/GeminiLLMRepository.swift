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
                    let result = try processTextWithLlm(
                        apiKey: apiKey,
                        prompt: prompt,
                        systemInstruction: nil,
                        temperature: Float(temperature ?? 0.3)
                    )
                    continuation.resume(returning: result)
                } catch let coreError as CoreError {
                    let userError = Self.mapToUserFacingError(coreError)
                    continuation.resume(throwing: userError)
                } catch {
                    continuation.resume(throwing: UserFacingError.unknown(error.localizedDescription))
                }
            }
        }
    }

    /// Maps CoreError to UserFacingError based on HTTP status codes.
    /// Gemini API specific error handling:
    /// - 401: Invalid API key
    /// - 403: Permission/region blocked
    /// - 429: Rate limited
    /// - 5xx: Service unavailable
    private static func mapToUserFacingError(_ coreError: CoreError) -> UserFacingError {
        switch coreError {
        case .Api(let message):
            let lowercased = message.lowercased()
            if lowercased.contains("401") {
                return .invalidAPIKey
            } else if lowercased.contains("400") || lowercased.contains("403") {
                return .regionBlocked
            } else if lowercased.contains("429") {
                return .rateLimited
            } else if (lowercased.contains("500") ||
                      lowercased.contains("502") ||
                      lowercased.contains("503") ||
                      lowercased.contains("504")) {
                return .serviceUnavailable
            }
            return .unknown(message)

        case .Http:
            return .networkError

        default:
            return .unknown(coreError.localizedDescription)
        }
    }
}
