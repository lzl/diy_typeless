import Foundation

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(audioData: AudioData, apiKey: String, language: String?) async throws -> String {
        guard !audioData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try transcribeAudioBytes(
                        apiKey: apiKey,
                        audioBytes: audioData.bytes,
                        language: language
                    )
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: TranscriptionError.apiError(error.localizedDescription))
                }
            }
        }
    }
}
