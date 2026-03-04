import Foundation
import DIYTypelessCore

/// Repository implementation that calls Gemini API via Rust FFI.
/// Wraps synchronous FFI calls in async continuations on background thread.
///
/// Note: This repository throws CoreError directly. Error mapping to UserFacingError
/// should be handled by the UseCase layer to maintain proper dependency boundaries.
final class GeminiLLMRepository: LLMRepository {
    func generate(
        apiKey: String,
        prompt: String,
        temperature: Double?,
        cancellationToken: DIYTypelessCore.CancellationToken?
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
                        let result = try processTextWithLlmCancellable(
                            apiKey: apiKey,
                            prompt: prompt,
                            systemInstruction: nil,
                            temperature: Float(temperature ?? 0.3),
                            cancellationToken: ffiCancellationToken
                        )
                        continuation.resume(returning: result)
                    } catch let coreError as CoreError {
                        if case .Cancelled = coreError {
                            continuation.resume(throwing: CancellationError())
                            return
                        }

                        // Pass through CoreError directly - UseCase will map to UserFacingError
                        continuation.resume(throwing: coreError)
                    } catch {
                        // Wrap unknown errors in CoreError.Api
                        continuation.resume(throwing: CoreError.Api(error.localizedDescription))
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
