import Foundation

final class StopRecordingUseCaseImpl: StopRecordingUseCaseProtocol {
    func execute() async throws -> AudioData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioData = try stopRecording()
                    continuation.resume(returning: audioData)
                } catch {
                    continuation.resume(throwing: RecordingError.stopFailed(error.localizedDescription))
                }
            }
        }
    }
}
