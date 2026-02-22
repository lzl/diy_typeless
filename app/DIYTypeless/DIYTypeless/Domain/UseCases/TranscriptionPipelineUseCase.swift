import Foundation

final class TranscriptionPipelineUseCase: TranscriptionUseCaseProtocol {
    func execute(groqKey: String, geminiKey: String, context: String?) async throws -> TranscriptionResult {
        // 1. Stop recording and get WAV data (async wrapped FFI)
        let wavData = try await stopRecordingAsync()

        // 2. Transcribe audio (async wrapped FFI)
        let rawText = try await transcribeAsync(apiKey: groqKey, wavBytes: wavData.bytes, language: nil)

        // 3. Polish text (async wrapped FFI)
        let polishedText = try await polishAsync(apiKey: geminiKey, rawText: rawText, context: context)

        // 4. Determine output result and return
        let outputResult: OutputResult = .pasted // Default, actual delivery handled by caller

        return TranscriptionResult(
            rawText: rawText,
            polishedText: polishedText,
            outputResult: outputResult
        )
    }

    // MARK: - Async FFI Wrappers

    private func stopRecordingAsync() async throws -> WavData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let wavData = try stopRecording()
                    continuation.resume(returning: wavData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func transcribeAsync(apiKey: String, wavBytes: Data, language: String?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try transcribeWavBytes(apiKey: apiKey, wavBytes: wavBytes, language: language)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func polishAsync(apiKey: String, rawText: String, context: String?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let polished = try polishText(apiKey: apiKey, rawText: rawText, context: context)
                    continuation.resume(returning: polished)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Recording Control UseCase

protocol RecordingControlUseCaseProtocol: Sendable {
    func startRecording() async throws
    func warmupConnections() async
}

final class RecordingControlUseCase: RecordingControlUseCaseProtocol {
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
