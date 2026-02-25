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
                } catch {
                    continuation.resume(throwing: PolishingError.apiError(error.localizedDescription))
                }
            }
        }
    }
}
