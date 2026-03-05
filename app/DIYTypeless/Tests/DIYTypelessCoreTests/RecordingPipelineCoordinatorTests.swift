import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

@MainActor
final class RecordingPipelineCoordinatorTests: XCTestCase {
    func testExecute_withSelectedText_usesVoiceCommandPath() async throws {
        let stopRecordingUseCase = MockStopRecordingUseCase()
        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.result = "rewrite this"
        let polishTextUseCase = MockPolishTextUseCase()
        let processVoiceCommandUseCase = MockProcessVoiceCommandUseCase()
        processVoiceCommandUseCase.result = VoiceCommandResult(
            processedText: "rewritten text",
            action: .replaceSelection
        )
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase
        )

        var progressEvents: [RecordingPipelineProgress] = []
        let result = try await sut.execute(
            request: RecordingPipelineRequest(
                groqKey: "groq-key",
                geminiKey: "gemini-key",
                selectedTextContext: SelectedTextContext(
                    text: "original selection",
                    isEditable: false,
                    isSecure: false,
                    applicationName: "Notes"
                ),
                appContext: "App context",
                cancellationToken: nil
            ),
            onProgress: { progress in
                progressEvents.append(progress)
            }
        )

        guard case .voiceCommand(let voiceResult) = result else {
            return XCTFail("Expected voice command result")
        }
        XCTAssertEqual(voiceResult.processedText, "rewritten text")
        XCTAssertEqual(progressEvents, [.recordingStopped, .transcribing, .processingCommand("rewrite this")])
        XCTAssertEqual(stopRecordingUseCase.executeCallCount, 1)
        XCTAssertEqual(transcribeAudioUseCase.executeCallCount, 1)
        XCTAssertEqual(polishTextUseCase.executeCallCount, 0)
        XCTAssertEqual(processVoiceCommandUseCase.executeCallCount, 1)
        XCTAssertEqual(processVoiceCommandUseCase.receivedSelectedText, "original selection")
    }

    func testExecute_withoutSelection_fallsBackToPolishPath() async throws {
        let stopRecordingUseCase = MockStopRecordingUseCase()
        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.result = "raw transcript"
        let polishTextUseCase = MockPolishTextUseCase()
        polishTextUseCase.result = "polished result"
        let processVoiceCommandUseCase = MockProcessVoiceCommandUseCase()
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase
        )

        var progressEvents: [RecordingPipelineProgress] = []
        let result = try await sut.execute(
            request: RecordingPipelineRequest(
                groqKey: "groq-key",
                geminiKey: "gemini-key",
                selectedTextContext: .empty,
                appContext: "Captured app context",
                cancellationToken: nil
            ),
            onProgress: { progress in
                progressEvents.append(progress)
            }
        )

        guard case .polishedText(let polishedText) = result else {
            return XCTFail("Expected polished text result")
        }
        XCTAssertEqual(polishedText, "polished result")
        XCTAssertEqual(progressEvents, [.recordingStopped, .transcribing, .polishing])
        XCTAssertEqual(stopRecordingUseCase.executeCallCount, 1)
        XCTAssertEqual(transcribeAudioUseCase.executeCallCount, 1)
        XCTAssertEqual(polishTextUseCase.executeCallCount, 1)
        XCTAssertEqual(polishTextUseCase.receivedRawText, "raw transcript")
        XCTAssertEqual(polishTextUseCase.receivedContext, "Captured app context")
        XCTAssertEqual(processVoiceCommandUseCase.executeCallCount, 0)
    }

    func testExecute_withSecureSelection_usesPolishPath() async throws {
        let stopRecordingUseCase = MockStopRecordingUseCase()
        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.result = "raw transcript"
        let polishTextUseCase = MockPolishTextUseCase()
        polishTextUseCase.result = "polished result"
        let processVoiceCommandUseCase = MockProcessVoiceCommandUseCase()
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase
        )

        var progressEvents: [RecordingPipelineProgress] = []
        let result = try await sut.execute(
            request: RecordingPipelineRequest(
                groqKey: "groq-key",
                geminiKey: "gemini-key",
                selectedTextContext: SelectedTextContext(
                    text: "secret",
                    isEditable: false,
                    isSecure: true,
                    applicationName: "1Password"
                ),
                appContext: "Captured app context",
                cancellationToken: nil
            ),
            onProgress: { progress in
                progressEvents.append(progress)
            }
        )

        guard case .polishedText(let polishedText) = result else {
            return XCTFail("Expected polished text result")
        }
        XCTAssertEqual(polishedText, "polished result")
        XCTAssertEqual(progressEvents, [.recordingStopped, .transcribing, .polishing])
        XCTAssertEqual(polishTextUseCase.executeCallCount, 1)
        XCTAssertEqual(processVoiceCommandUseCase.executeCallCount, 0)
    }

    func testMapToUserFacingError_transcriptionErrors_mapsToExpectedMessage() {
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: MockStopRecordingUseCase(),
            transcribeAudioUseCase: MockTranscribeAudioUseCase(),
            polishTextUseCase: MockPolishTextUseCase(),
            processVoiceCommandUseCase: MockProcessVoiceCommandUseCase()
        )

        let mapped = sut.mapToUserFacingError(TranscriptionError.emptyAudio)
        XCTAssertEqual(mapped, .unknown("Transcription failed"))
    }

    func testMapToUserFacingError_polishingErrors_mapsToExpectedMessage() {
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: MockStopRecordingUseCase(),
            transcribeAudioUseCase: MockTranscribeAudioUseCase(),
            polishTextUseCase: MockPolishTextUseCase(),
            processVoiceCommandUseCase: MockProcessVoiceCommandUseCase()
        )

        let mapped = sut.mapToUserFacingError(PolishingError.invalidResponse)
        XCTAssertEqual(mapped, .unknown("Polishing failed"))
    }

    func testMapToUserFacingError_cancellation_mapsToNil() {
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: MockStopRecordingUseCase(),
            transcribeAudioUseCase: MockTranscribeAudioUseCase(),
            polishTextUseCase: MockPolishTextUseCase(),
            processVoiceCommandUseCase: MockProcessVoiceCommandUseCase()
        )

        let mapped = sut.mapToUserFacingError(CancellationError())
        XCTAssertNil(mapped)
    }

    func testMapToUserFacingError_userFacingError_passthrough() {
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: MockStopRecordingUseCase(),
            transcribeAudioUseCase: MockTranscribeAudioUseCase(),
            polishTextUseCase: MockPolishTextUseCase(),
            processVoiceCommandUseCase: MockProcessVoiceCommandUseCase()
        )

        let mapped = sut.mapToUserFacingError(UserFacingError.rateLimited)
        XCTAssertEqual(mapped, .rateLimited)
    }

    func testMapToUserFacingError_unknownError_wrapsDescription() {
        let sut = RecordingPipelineCoordinator(
            stopRecordingUseCase: MockStopRecordingUseCase(),
            transcribeAudioUseCase: MockTranscribeAudioUseCase(),
            polishTextUseCase: MockPolishTextUseCase(),
            processVoiceCommandUseCase: MockProcessVoiceCommandUseCase()
        )

        let mapped = sut.mapToUserFacingError(StubError())
        XCTAssertEqual(mapped, .unknown("stub failure"))
    }
}

private struct StubError: LocalizedError {
    var errorDescription: String? { "stub failure" }
}
