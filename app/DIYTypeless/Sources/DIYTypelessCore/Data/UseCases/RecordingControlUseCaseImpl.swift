import Foundation

public final class RecordingControlUseCaseImpl: RecordingControlUseCaseProtocol {
    public init() {}

    public func startRecording() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try CoreFFIRuntime.startRecording()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func warmupConnections(llmProvider: ApiProvider) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                _ = try? CoreFFIRuntime.warmupGroqConnection()
                _ = try? CoreFFIRuntime.warmupLLMConnection(provider: llmProvider)
                continuation.resume()
            }
        }
    }
}
