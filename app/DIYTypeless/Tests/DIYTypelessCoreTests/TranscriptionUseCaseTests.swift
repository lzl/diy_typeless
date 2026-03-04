import XCTest
#if canImport(DIYTypeless)
@testable import DIYTypeless
#elseif canImport(DIYTypelessCore)
@testable import DIYTypelessCore
#endif

final class TranscriptionUseCaseTests: XCTestCase {
    func testExecute_happyPath_composesStopTranscribePolishAndReturnsResult() async throws {
        let stop = MockStopRecordingUseCase()
        let transcribe = MockTranscribeAudioUseCase()
        let polish = MockPolishTextUseCase()
        transcribe.result = "raw"
        polish.result = "polished"

        let sut = TranscriptionUseCase(
            stopRecordingUseCase: stop,
            transcribeAudioUseCase: transcribe,
            polishTextUseCase: polish
        )

        let result = try await sut.execute(
            groqKey: "groq-key",
            geminiKey: "gemini-key",
            context: "app=Notes"
        )

        XCTAssertEqual(stop.executeCallCount, 1)
        XCTAssertEqual(transcribe.executeCallCount, 1)
        XCTAssertEqual(transcribe.receivedAPIKey, "groq-key")
        XCTAssertEqual(polish.executeCallCount, 1)
        XCTAssertEqual(polish.receivedRawText, "raw")
        XCTAssertEqual(polish.receivedAPIKey, "gemini-key")
        XCTAssertEqual(polish.receivedContext, "app=Notes")

        XCTAssertEqual(result.rawText, "raw")
        XCTAssertEqual(result.polishedText, "polished")
        XCTAssertEqual(result.outputResult, .pasted)
    }

    func testExecute_whenStopRecordingFails_propagatesErrorAndSkipsLaterStages() async {
        let stop = MockStopRecordingUseCase()
        stop.error = RecordingError.notRecording
        let transcribe = MockTranscribeAudioUseCase()
        let polish = MockPolishTextUseCase()

        let sut = TranscriptionUseCase(
            stopRecordingUseCase: stop,
            transcribeAudioUseCase: transcribe,
            polishTextUseCase: polish
        )

        do {
            _ = try await sut.execute(groqKey: "g", geminiKey: "m", context: nil)
            XCTFail("Expected RecordingError.notRecording")
        } catch let error as RecordingError {
            guard case .notRecording = error else {
                return XCTFail("Unexpected recording error: \(error)")
            }
            XCTAssertEqual(transcribe.executeCallCount, 0)
            XCTAssertEqual(polish.executeCallCount, 0)
        } catch {
            XCTFail("Expected RecordingError, got \(error)")
        }
    }
}
