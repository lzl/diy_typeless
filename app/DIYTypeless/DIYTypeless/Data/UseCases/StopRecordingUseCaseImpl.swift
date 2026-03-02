import Foundation

final class StopRecordingUseCaseImpl: StopRecordingUseCaseProtocol {
    func execute() async throws -> DomainAudioData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let ffiAudioData = try stopRecording()
                    let audioData = DomainAudioData(
                        bytes: ffiAudioData.bytes,
                        durationSeconds: ffiAudioData.durationSeconds
                    )
                    continuation.resume(returning: audioData)
                } catch {
                    continuation.resume(throwing: RecordingError.stopFailed(error.localizedDescription))
                }
            }
        }
    }
}
