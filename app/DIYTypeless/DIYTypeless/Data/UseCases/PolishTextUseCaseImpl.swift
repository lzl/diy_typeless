import Foundation

final class PolishTextUseCaseImpl: PolishTextUseCaseProtocol {
    func execute(rawText: String, apiKey: String, context: String?) async throws -> String {
        guard !rawText.isEmpty else {
            throw PolishingError.emptyInput
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let polished = try polishText(
                        apiKey: apiKey,
                        rawText: rawText,
                        context: context
                    )
                    continuation.resume(returning: polished)
                } catch let coreError as CoreError {
                    let userError = Self.mapToUserFacingError(coreError)
                    continuation.resume(throwing: PolishingError.apiError(userError))
                } catch {
                    let userError = UserFacingError.unknown(error.localizedDescription)
                    continuation.resume(throwing: PolishingError.apiError(userError))
                }
            }
        }
    }

    /// Maps CoreError to UserFacingError based on HTTP status codes and error types.
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
