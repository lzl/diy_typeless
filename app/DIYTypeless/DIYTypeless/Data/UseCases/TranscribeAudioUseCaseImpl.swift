import Foundation

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CoreCancellationToken?
    ) async throws -> String {
        guard !audioData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        let token = cancellationToken ?? CoreCancellationToken()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    if token.isCancelled() {
                        continuation.resume(throwing: TranscriptionError.cancelled)
                        return
                    }

                    do {
                        let text = try transcribeAudioBytesCancellable(
                            apiKey: apiKey,
                            audioBytes: audioData.bytes,
                            language: language,
                            cancellationToken: token
                        )
                        if token.isCancelled() {
                            continuation.resume(throwing: TranscriptionError.cancelled)
                        } else {
                            continuation.resume(returning: text)
                        }
                    } catch let coreError as CoreError {
                        if case .Cancelled = coreError {
                            continuation.resume(throwing: TranscriptionError.cancelled)
                        } else {
                            let userError = CoreErrorMapper.toUserFacingError(coreError)
                            continuation.resume(throwing: TranscriptionError.apiError(userError))
                        }
                    } catch {
                        let userError = UserFacingError.unknown(error.localizedDescription)
                        continuation.resume(throwing: TranscriptionError.apiError(userError))
                    }
                }
            }
        } onCancel: {
            token.cancel()
        }
    }

}
