import Foundation

final class TranscribeAudioUseCaseImpl: TranscribeAudioUseCaseProtocol {
    func execute(wavData: WavData, apiKey: String, language: String?) async throws -> String {
        guard !wavData.bytes.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try transcribeWavBytes(
                        apiKey: apiKey,
                        wavBytes: wavData.bytes,
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
