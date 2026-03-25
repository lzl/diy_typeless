import Foundation

/// Repository implementation that calls provider-backed LLM APIs via Rust FFI.
/// Wraps synchronous FFI calls in async continuations on background thread.
///
/// Note: This repository throws CoreError directly. Error mapping to UserFacingError
/// should be handled by the UseCase layer to maintain proper dependency boundaries.
public final class GeminiLLMRepository: LLMRepository {
    public init() {}

    public func generate(
        provider: ApiProvider,
        apiKey: String,
        prompt: String,
        temperature: Double?,
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
                        let result = try CoreFFIRuntime.processTextWithLlmCancellable(
                            provider: provider,
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

                        // Pass through DIYTypelessCore.CoreError - UseCase maps to UserFacingError.
                        continuation.resume(throwing: coreError)
                    } catch {
                        // Wrap unknown errors using the core module's error type.
                        continuation.resume(
                            throwing: CoreError.Api(error.localizedDescription)
                        )
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
