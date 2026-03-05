import Foundation
import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#else
@testable import DIYTypeless
#endif

private actor CoreFFIRuntimeTestLock {
    static let shared = CoreFFIRuntimeTestLock()

    func run<T>(_ operation: () async throws -> T) async rethrows -> T {
        try await operation()
    }
}

private struct RuntimeSnapshot {
    var startRecordingCalls = 0
    var stopRecordingCalls = 0
    var warmupGroqCalls = 0
    var warmupGeminiCalls = 0
    var transcribeCalls = 0
    var polishCalls = 0
    var llmCalls = 0

    var lastTranscribeApiKey: String?
    var lastTranscribeAudioBytes: Data?
    var lastTranscribeLanguage: String?

    var lastPolishApiKey: String?
    var lastPolishRawText: String?
    var lastPolishContext: String?

    var lastLlmApiKey: String?
    var lastLlmPrompt: String?
    var lastLlmSystemInstruction: String?
    var lastLlmTemperature: Float?
}

private final class RuntimeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshotValue = RuntimeSnapshot()

    func mutate(_ operation: (inout RuntimeSnapshot) -> Void) {
        lock.lock()
        operation(&snapshotValue)
        lock.unlock()
    }

    func snapshot() -> RuntimeSnapshot {
        lock.lock()
        let value = snapshotValue
        lock.unlock()
        return value
    }
}

private struct RuntimeBehavior {
    var startRecordingError: Error?
    var stopRecordingResult = DomainAudioData(bytes: Data([9, 8, 7]), durationSeconds: 1.25)
    var stopRecordingError: Error?
    var warmupGroqError: Error?
    var warmupGeminiError: Error?

    var transcribeResult = "transcribed"
    var transcribeError: Error?

    var polishResult = "polished"
    var polishError: Error?

    var llmResult = "llm-result"
    var llmError: Error?
}

private func configureRuntime(
    recorder: RuntimeRecorder,
    behavior: RuntimeBehavior = RuntimeBehavior()
) {
    CoreFFIRuntime.configure(
        CoreFFIRuntimeHandlers(
            startRecording: {
                recorder.mutate { $0.startRecordingCalls += 1 }
                if let error = behavior.startRecordingError {
                    throw error
                }
            },
            stopRecording: {
                recorder.mutate { $0.stopRecordingCalls += 1 }
                if let error = behavior.stopRecordingError {
                    throw error
                }
                return behavior.stopRecordingResult
            },
            warmupGroqConnection: {
                recorder.mutate { $0.warmupGroqCalls += 1 }
                if let error = behavior.warmupGroqError {
                    throw error
                }
            },
            warmupGeminiConnection: {
                recorder.mutate { $0.warmupGeminiCalls += 1 }
                if let error = behavior.warmupGeminiError {
                    throw error
                }
            },
            transcribeAudioBytesCancellable: { apiKey, audioBytes, language, _ in
                recorder.mutate {
                    $0.transcribeCalls += 1
                    $0.lastTranscribeApiKey = apiKey
                    $0.lastTranscribeAudioBytes = audioBytes
                    $0.lastTranscribeLanguage = language
                }
                if let error = behavior.transcribeError {
                    throw error
                }
                return behavior.transcribeResult
            },
            polishTextCancellable: { apiKey, rawText, context, _ in
                recorder.mutate {
                    $0.polishCalls += 1
                    $0.lastPolishApiKey = apiKey
                    $0.lastPolishRawText = rawText
                    $0.lastPolishContext = context
                }
                if let error = behavior.polishError {
                    throw error
                }
                return behavior.polishResult
            },
            processTextWithLlmCancellable: { apiKey, prompt, systemInstruction, temperature, _ in
                recorder.mutate {
                    $0.llmCalls += 1
                    $0.lastLlmApiKey = apiKey
                    $0.lastLlmPrompt = prompt
                    $0.lastLlmSystemInstruction = systemInstruction
                    $0.lastLlmTemperature = temperature
                }
                if let error = behavior.llmError {
                    throw error
                }
                return behavior.llmResult
            }
        )
    )
}

private struct FakeRuntimeError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class RecordingControlUseCaseImplTests: XCTestCase {
    func testStartRecording_callsRuntimeStartRecording() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(recorder: recorder)
            let sut = RecordingControlUseCaseImpl()

            try await sut.startRecording()

            XCTAssertEqual(recorder.snapshot().startRecordingCalls, 1)
        }
    }

    func testStartRecording_whenRuntimeThrows_propagatesError() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(startRecordingError: CoreError.RecordingAlreadyActive)
            )
            let sut = RecordingControlUseCaseImpl()

            do {
                try await sut.startRecording()
                XCTFail("Expected CoreError.RecordingAlreadyActive")
            } catch let error as CoreError {
                XCTAssertEqual(error, .RecordingAlreadyActive)
            } catch {
                XCTFail("Expected CoreError, got \(error)")
            }
        }
    }

    func testWarmupConnections_whenGroqFails_stillWarmsGemini() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(
                    warmupGroqError: CoreError.Http("timeout")
                )
            )
            let sut = RecordingControlUseCaseImpl()

            await sut.warmupConnections()

            let snapshot = recorder.snapshot()
            XCTAssertEqual(snapshot.warmupGroqCalls, 1)
            XCTAssertEqual(snapshot.warmupGeminiCalls, 1)
        }
    }
}

final class StopRecordingUseCaseImplTests: XCTestCase {
    func testExecute_whenRuntimeReturnsAudio_returnsDomainAudioData() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            let expected = DomainAudioData(bytes: Data([1, 2, 3, 4]), durationSeconds: 2.0)
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(stopRecordingResult: expected)
            )
            let sut = StopRecordingUseCaseImpl()

            let result = try await sut.execute()

            XCTAssertEqual(result.bytes, expected.bytes)
            XCTAssertEqual(result.durationSeconds, expected.durationSeconds, accuracy: 0.0001)
            XCTAssertEqual(recorder.snapshot().stopRecordingCalls, 1)
        }
    }

    func testExecute_whenRuntimeThrows_wrapsAsStopFailed() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(stopRecordingError: CoreError.RecordingNotActive)
            )
            let sut = StopRecordingUseCaseImpl()

            do {
                _ = try await sut.execute()
                XCTFail("Expected RecordingError.stopFailed")
            } catch let error as RecordingError {
                switch error {
                case .stopFailed(let message):
                    XCTAssertTrue(message.contains("RecordingNotActive"))
                default:
                    XCTFail("Expected stopFailed, got \(error)")
                }
            } catch {
                XCTFail("Expected RecordingError, got \(error)")
            }
        }
    }
}

final class TranscribeAudioUseCaseImplTests: XCTestCase {
    func testExecute_success_passesArgumentsToRuntimeAndReturnsText() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(transcribeResult: "hello world")
            )
            let sut = TranscribeAudioUseCaseImpl()
            let audio = DomainAudioData(bytes: Data([4, 5, 6]), durationSeconds: 0.75)

            let result = try await sut.execute(
                audioData: audio,
                apiKey: "groq-key",
                language: "en",
                cancellationToken: nil
            )

            let snapshot = recorder.snapshot()
            XCTAssertEqual(result, "hello world")
            XCTAssertEqual(snapshot.transcribeCalls, 1)
            XCTAssertEqual(snapshot.lastTranscribeApiKey, "groq-key")
            XCTAssertEqual(snapshot.lastTranscribeAudioBytes, audio.bytes)
            XCTAssertEqual(snapshot.lastTranscribeLanguage, "en")
        }
    }

    func testExecute_whenApi401_mapsToInvalidApiKey() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(transcribeError: CoreError.Api("401 unauthorized"))
            )
            let sut = TranscribeAudioUseCaseImpl()
            let audio = DomainAudioData(bytes: Data([7, 7, 7]), durationSeconds: 0.5)

            do {
                _ = try await sut.execute(
                    audioData: audio,
                    apiKey: "groq-key",
                    language: nil,
                    cancellationToken: nil
                )
                XCTFail("Expected TranscriptionError.apiError(.invalidAPIKey)")
            } catch let error as TranscriptionError {
                XCTAssertEqual(error, .apiError(.invalidAPIKey))
            } catch {
                XCTFail("Expected TranscriptionError, got \(error)")
            }
        }
    }

    func testExecute_whenTokenAlreadyCancelled_throwsWithoutCallingRuntime() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(recorder: recorder)
            let sut = TranscribeAudioUseCaseImpl()
            let audio = DomainAudioData(bytes: Data([1]), durationSeconds: 0.1)
            let token = FakeCancellationToken(isCancelled: true)

            do {
                _ = try await sut.execute(
                    audioData: audio,
                    apiKey: "groq-key",
                    language: nil,
                    cancellationToken: token
                )
                XCTFail("Expected CancellationError")
            } catch is CancellationError {
                XCTAssertEqual(recorder.snapshot().transcribeCalls, 0)
            } catch {
                XCTFail("Expected CancellationError, got \(error)")
            }
        }
    }
}

final class PolishTextUseCaseImplTests: XCTestCase {
    func testExecute_whenInputIsEmpty_throwsAndSkipsRuntimeCall() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(recorder: recorder)
            let sut = PolishTextUseCaseImpl()

            do {
                _ = try await sut.execute(
                    rawText: "",
                    apiKey: "gem-key",
                    context: nil,
                    cancellationToken: nil
                )
                XCTFail("Expected PolishingError.emptyInput")
            } catch let error as PolishingError {
                XCTAssertEqual(error, .emptyInput)
                XCTAssertEqual(recorder.snapshot().polishCalls, 0)
            } catch {
                XCTFail("Expected PolishingError, got \(error)")
            }
        }
    }

    func testExecute_whenHttpError_mapsToNetworkError() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(polishError: CoreError.Http("timeout"))
            )
            let sut = PolishTextUseCaseImpl()

            do {
                _ = try await sut.execute(
                    rawText: "hello",
                    apiKey: "gem-key",
                    context: "notes",
                    cancellationToken: nil
                )
                XCTFail("Expected PolishingError.apiError(.networkError)")
            } catch let error as PolishingError {
                XCTAssertEqual(error, .apiError(.networkError))
            } catch {
                XCTFail("Expected PolishingError, got \(error)")
            }
        }
    }

    func testExecute_success_passesContextAndReturnsPolishedText() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(polishResult: "polished output")
            )
            let sut = PolishTextUseCaseImpl()

            let result = try await sut.execute(
                rawText: "raw text",
                apiKey: "gem-key",
                context: "mail",
                cancellationToken: nil
            )

            let snapshot = recorder.snapshot()
            XCTAssertEqual(result, "polished output")
            XCTAssertEqual(snapshot.polishCalls, 1)
            XCTAssertEqual(snapshot.lastPolishApiKey, "gem-key")
            XCTAssertEqual(snapshot.lastPolishRawText, "raw text")
            XCTAssertEqual(snapshot.lastPolishContext, "mail")
        }
    }
}

final class GeminiLLMRepositoryTests: XCTestCase {
    func testGenerate_whenTemperatureNil_usesDefaultAndReturnsResult() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(llmResult: "done")
            )
            let sut = GeminiLLMRepository()

            let result = try await sut.generate(
                apiKey: "gem-key",
                prompt: "prompt",
                temperature: nil,
                cancellationToken: nil
            )

            let snapshot = recorder.snapshot()
            XCTAssertEqual(result, "done")
            XCTAssertEqual(snapshot.llmCalls, 1)
            XCTAssertEqual(snapshot.lastLlmApiKey, "gem-key")
            XCTAssertEqual(snapshot.lastLlmPrompt, "prompt")
            XCTAssertEqual(snapshot.lastLlmSystemInstruction, nil)
            XCTAssertEqual(snapshot.lastLlmTemperature ?? -1, 0.3, accuracy: 0.0001)
        }
    }

    func testGenerate_whenCustomTemperatureProvided_forwardsValue() async throws {
        try await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(recorder: recorder)
            let sut = GeminiLLMRepository()

            _ = try await sut.generate(
                apiKey: "gem-key",
                prompt: "prompt",
                temperature: 0.9,
                cancellationToken: nil
            )

            XCTAssertEqual(recorder.snapshot().lastLlmTemperature ?? -1, 0.9, accuracy: 0.0001)
        }
    }

    func testGenerate_whenUnknownError_wrapsAsCoreApiError() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(
                recorder: recorder,
                behavior: RuntimeBehavior(llmError: FakeRuntimeError(message: "boom"))
            )
            let sut = GeminiLLMRepository()

            do {
                _ = try await sut.generate(
                    apiKey: "gem-key",
                    prompt: "prompt",
                    temperature: nil,
                    cancellationToken: nil
                )
                XCTFail("Expected CoreError.Api")
            } catch let error as CoreError {
                guard case .Api(let message) = error else {
                    return XCTFail("Expected Api error, got \(error)")
                }
                XCTAssertTrue(message.contains("boom"))
            } catch {
                XCTFail("Expected CoreError, got \(error)")
            }
        }
    }

    func testGenerate_whenTokenAlreadyCancelled_throwsWithoutCallingRuntime() async {
        await CoreFFIRuntimeTestLock.shared.run {
            let recorder = RuntimeRecorder()
            configureRuntime(recorder: recorder)
            let sut = GeminiLLMRepository()
            let token = FakeCancellationToken(isCancelled: true)

            do {
                _ = try await sut.generate(
                    apiKey: "gem-key",
                    prompt: "prompt",
                    temperature: nil,
                    cancellationToken: token
                )
                XCTFail("Expected CancellationError")
            } catch is CancellationError {
                XCTAssertEqual(recorder.snapshot().llmCalls, 0)
            } catch {
                XCTFail("Expected CancellationError, got \(error)")
            }
        }
    }
}
