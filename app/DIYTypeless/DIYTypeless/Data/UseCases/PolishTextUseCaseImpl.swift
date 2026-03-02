import Foundation

final class PolishTextUseCaseImpl: PolishTextUseCaseProtocol {
    func execute(
        rawText: String,
        apiKey: String,
        context: String?,
        cancellationToken: CoreCancellationToken?
    ) async throws -> String {
        guard !rawText.isEmpty else {
            throw PolishingError.emptyInput
        }

        let token = cancellationToken ?? CoreCancellationToken()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    if token.isCancelled() {
                        continuation.resume(throwing: PolishingError.cancelled)
                        return
                    }

                    do {
                        let polished = try polishTextCancellable(
                            apiKey: apiKey,
                            rawText: rawText,
                            context: context,
                            cancellationToken: token
                        )
                        if token.isCancelled() {
                            continuation.resume(throwing: PolishingError.cancelled)
                        } else {
                            continuation.resume(returning: polished)
                        }
                    } catch let coreError as CoreError {
                        if case .Cancelled = coreError {
                            continuation.resume(throwing: PolishingError.cancelled)
                        } else {
                            let userError = CoreErrorMapper.toUserFacingError(coreError)
                            continuation.resume(throwing: PolishingError.apiError(userError))
                        }
                    } catch {
                        let userError = UserFacingError.unknown(error.localizedDescription)
                        continuation.resume(throwing: PolishingError.apiError(userError))
                    }
                }
            }
        } onCancel: {
            token.cancel()
        }
    }

}
