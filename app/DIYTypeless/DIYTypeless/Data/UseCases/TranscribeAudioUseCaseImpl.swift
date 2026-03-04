import Foundation
import DIYTypelessCore

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        guard !audioData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        let effectiveToken = cancellationToken ?? CancellationToken()

        if effectiveToken.isCancelled() {
            throw CancellationError()
        }
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let text = try transcribeAudioBytesCancellable(
                            apiKey: apiKey,
                            audioBytes: audioData.bytes,
                            language: language,
                            cancellationToken: effectiveToken
                        )
                        continuation.resume(returning: text)
                    } catch let coreError as CoreError {
                        if case .Cancelled = coreError {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

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
        } onCancel: {
            effectiveToken.cancel()
        }
    }

}
