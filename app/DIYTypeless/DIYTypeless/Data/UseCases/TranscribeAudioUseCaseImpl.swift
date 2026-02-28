import Foundation

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(audioData: AudioData, apiKey: String, language: String?) async throws -> String {
        guard !audioData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try transcribeAudioBytes(
                        apiKey: apiKey,
                        audioBytes: audioData.bytes,
                        language: language
                    )
                    continuation.resume(returning: text)
                } catch let coreError as CoreError {
                    let userError = Self.mapToUserFacingError(coreError)
                    continuation.resume(throwing: TranscriptionError.apiError(userError))
                } catch {
                    let userError = UserFacingError.unknown(error.localizedDescription)
                    continuation.resume(throwing: TranscriptionError.apiError(userError))
                }
            }
        }
    }

    /// Maps CoreError to UserFacingError based on HTTP status codes and error types.
    /// Groq API specific error handling:
    /// - 401: Invalid API key
    /// - 403: Region blocked (common for certain regions with Groq)
    /// - 429: Rate limited
    /// - 5xx: Service unavailable
    private static func mapToUserFacingError(_ coreError: CoreError) -> UserFacingError {
        switch coreError {
        case .Api(let message):
            let lowercased = message.lowercased()
            if lowercased.contains("401") {
                return .invalidAPIKey
            } else if lowercased.contains("403") {
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
