import Foundation

final class RecordingControlUseCaseImpl: RecordingControlUseCaseProtocol {
    func startRecording() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try DIYTypeless.startRecording()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func warmupConnections() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                _ = try? warmupGroqConnection()
                _ = try? warmupGeminiConnection()
                continuation.resume()
            }
        }
    }
}
