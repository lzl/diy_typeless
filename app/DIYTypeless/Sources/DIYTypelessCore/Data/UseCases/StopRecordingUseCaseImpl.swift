import Foundation

public final class StopRecordingUseCaseImpl: StopRecordingUseCaseProtocol {
    public init() {}

    public func execute() async throws -> DomainAudioData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioData = try CoreFFIRuntime.stopRecording()
                    continuation.resume(returning: audioData)
                } catch {
                    continuation.resume(throwing: RecordingError.stopFailed(error.localizedDescription))
                }
            }
        }
    }
}
