import Foundation

public final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    public init() {}

    public func execute(
        audioData: DomainAudioData,
        apiKey: String,
        language: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        let ffiCancellationToken = await MainActor.run { CancellationToken() }
        let cancellationPropagationTask = Task.detached(priority: .userInitiated) { [cancellationToken] in
            guard let cancellationToken else { return }
            while !Task.isCancelled {
                if cancellationToken.isCancelled() {
                    await MainActor.run {
                        ffiCancellationToken.cancel()
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        guard !audioData.bytes.isEmpty else {
            cancellationPropagationTask.cancel()
            throw TranscriptionError.emptyAudio
        }

        if cancellationToken?.isCancelled() == true {
            cancellationPropagationTask.cancel()
            throw CancellationError()
        }
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            defer { cancellationPropagationTask.cancel() }

            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let text = try CoreFFIRuntime.transcribeAudioBytesCancellable(
                            apiKey: apiKey,
                            audioBytes: audioData.bytes,
                            language: language,
                            cancellationToken: ffiCancellationToken
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
            cancellationPropagationTask.cancel()
            Task { @MainActor in
                ffiCancellationToken.cancel()
            }
        }
    }

}
