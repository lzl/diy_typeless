import Foundation
import DIYTypelessCore

private let coreFFIRuntimeBootstrapLock = NSLock()
private var coreFFIRuntimeConfigured = false

func configureCoreFFIRuntimeIfNeeded() {
    coreFFIRuntimeBootstrapLock.lock()
    defer { coreFFIRuntimeBootstrapLock.unlock() }
    guard !coreFFIRuntimeConfigured else { return }

    CoreFFIRuntime.configure(
        CoreFFIRuntimeHandlers(
            startRecording: {
                try DIYTypeless.startRecording()
            },
            stopRecording: {
                let ffiAudioData = try stopRecording()
                return DomainAudioData(
                    bytes: ffiAudioData.bytes,
                    durationSeconds: ffiAudioData.durationSeconds
                )
            },
            warmupGroqConnection: {
                try warmupGroqConnection()
            },
            warmupLLMConnection: { provider in
                try warmupLlmConnection(provider: try ffiLlmProvider(from: provider))
            },
            transcribeAudioBytesCancellable: { apiKey, audioBytes, language, cancellationToken in
                try withBridgedCancellation(cancellationToken: cancellationToken) { ffiCancellationToken in
                    do {
                        return try transcribeAudioBytesCancellable(
                            apiKey: apiKey,
                            audioBytes: audioBytes,
                            language: language,
                            cancellationToken: ffiCancellationToken
                        )
                    } catch let error as CoreError {
                        throw mapCoreError(error)
                    }
                }
            },
            polishTextCancellable: { provider, apiKey, rawText, context, cancellationToken in
                try withBridgedCancellation(cancellationToken: cancellationToken) { ffiCancellationToken in
                    do {
                        return try polishTextCancellable(
                            provider: try ffiLlmProvider(from: provider),
                            apiKey: apiKey,
                            rawText: rawText,
                            context: context,
                            cancellationToken: ffiCancellationToken
                        )
                    } catch let error as CoreError {
                        throw mapCoreError(error)
                    }
                }
            },
            processTextWithLlmCancellable: { provider, apiKey, prompt, systemInstruction, temperature, cancellationToken in
                try withBridgedCancellation(cancellationToken: cancellationToken) { ffiCancellationToken in
                    do {
                        return try processTextWithLlmCancellable(
                            provider: try ffiLlmProvider(from: provider),
                            apiKey: apiKey,
                            prompt: prompt,
                            systemInstruction: systemInstruction,
                            temperature: temperature,
                            cancellationToken: ffiCancellationToken
                        )
                    } catch let error as CoreError {
                        throw mapCoreError(error)
                    }
                }
            }
        )
    )

    coreFFIRuntimeConfigured = true
}

private func ffiLlmProvider(from provider: DIYTypelessCore.ApiProvider) throws -> DIYTypeless.LlmProvider {
    switch provider {
    case .gemini:
        return .googleAiStudio
    case .openai:
        return .openai
    case .groq:
        throw DIYTypelessCore.CoreError.Config("Groq is not a valid LLM provider.")
    }
}

private func withBridgedCancellation<T>(
    cancellationToken: DIYTypelessCore.CancellationToken,
    operation: (CancellationToken) throws -> T
) throws -> T {
    let ffiCancellationToken = CancellationToken()
    let cancellationPropagationTask = Task.detached(priority: .userInitiated) {
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

    defer { cancellationPropagationTask.cancel() }

    if cancellationToken.isCancelled() {
        throw DIYTypelessCore.CoreError.Cancelled
    }

    return try operation(ffiCancellationToken)
}

private func mapCoreError(_ error: CoreError) -> DIYTypelessCore.CoreError {
    switch error {
    case .Cancelled:
        return .Cancelled
    case .AudioDeviceUnavailable:
        return .AudioDeviceUnavailable
    case .RecordingAlreadyActive:
        return .RecordingAlreadyActive
    case .RecordingNotActive:
        return .RecordingNotActive
    case .AudioCapture(let message):
        return .AudioCapture(message)
    case .AudioProcessing(let message):
        return .AudioProcessing(message)
    case .Http(let message):
        return .Http(message)
    case .Api(let message):
        return .Api(message)
    case .Serialization(let message):
        return .Serialization(message)
    case .EmptyResponse:
        return .EmptyResponse
    case .Transcription(let message):
        return .Transcription(message)
    case .Config(let message):
        return .Config(message)
    }
}
