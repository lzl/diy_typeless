import Foundation

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(audioData: DomainAudioData, apiKey: String, language: String?) async throws -> String {
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
                    let userError: UserFacingError
                    switch coreError {
                    case .Api(let message):
                        userError = CoreErrorMapper.toUserFacingError(category: .api, message: message)
                    case .Http(let message):
                        userError = CoreErrorMapper.toUserFacingError(category: .network, message: message)
                    default:
                        userError = CoreErrorMapper.toUserFacingError(
                            category: .unknown,
                            message: coreError.localizedDescription
                        )
                    }
                    continuation.resume(throwing: TranscriptionError.apiError(userError))
                } catch {
                    let userError = UserFacingError.unknown(error.localizedDescription)
                    continuation.resume(throwing: TranscriptionError.apiError(userError))
                }
            }
        }
    }

}
