import Foundation
import DIYTypelessCore

final class PolishTextUseCaseImpl: PolishTextUseCaseProtocol {
    func execute(
        rawText: String,
        apiKey: String,
        context: String?,
        cancellationToken: CancellationToken?
    ) async throws -> String {
        guard !rawText.isEmpty else {
            throw PolishingError.emptyInput
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
                        let polished = try polishTextCancellable(
                            apiKey: apiKey,
                            rawText: rawText,
                            context: context,
                            cancellationToken: effectiveToken
                        )
                        continuation.resume(returning: polished)
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
                        continuation.resume(throwing: PolishingError.apiError(userError))
                    } catch {
                        let userError = UserFacingError.unknown(error.localizedDescription)
                        continuation.resume(throwing: PolishingError.apiError(userError))
                    }
                }
            }
        } onCancel: {
            effectiveToken.cancel()
        }
    }

}
