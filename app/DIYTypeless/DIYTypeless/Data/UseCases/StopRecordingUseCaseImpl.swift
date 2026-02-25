import Foundation

final class StopRecordingUseCaseImpl: StopRecordingUseCaseProtocol {
    func execute() async throws -> WavData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let wavData = try stopRecording()
                    continuation.resume(returning: wavData)
                } catch {
                    continuation.resume(throwing: RecordingError.stopFailed(error.localizedDescription))
                }
            }
        }
    }
}
