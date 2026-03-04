import XCTest
#if canImport(DIYTypeless)
@testable import DIYTypeless
#elseif canImport(DIYTypelessHeadlessCore)
@testable import DIYTypelessHeadlessCore
#endif

@MainActor
final class RecordingStateTests: XCTestCase {
    func testHandleKeyDown_whenPermissionsMissing_showsInvalidKeyAndRequestsOnboarding() async {
        let permissionRepository = MockPermissionRepository(
            currentStatus: PermissionStatus(accessibility: false, microphone: false)
        )
        let (sut, dependencies) = makeSUT(permissionRepository: permissionRepository)

        var onboardingRequestCount = 0
        sut.onRequireOnboarding = { onboardingRequestCount += 1 }

        await sut.handleKeyDown()

        guard case let .error(error) = sut.capsuleState else {
            return XCTFail("Expected capsule state to be .error")
        }
        XCTAssertEqual(error, .invalidAPIKey)
        XCTAssertEqual(onboardingRequestCount, 1)
        XCTAssertEqual(dependencies.recordingControlUseCase.startRecordingCallCount, 0)
    }

    func testHandleKeyDown_withValidSetup_startsRecordingAndCapturesContext() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "  groq-key  "
        apiKeyRepository.keys[.gemini] = " gemini-key "

        let (sut, dependencies) = makeSUT(apiKeyRepository: apiKeyRepository)

        await sut.handleKeyDown()
        await waitUntil { dependencies.recordingControlUseCase.warmupCallCount == 1 }

        XCTAssertEqual(dependencies.recordingControlUseCase.startRecordingCallCount, 1)
        XCTAssertEqual(dependencies.appContextRepository.captureCallCount, 1)
        XCTAssertEqual(dependencies.prefetchScheduler.scheduleCallCount, 1)
        XCTAssertEqual(sut.capsuleState, .recording)
    }

    func testHandleKeyUp_withSelectedText_usesVoiceCommandModeAndUpdatesResultLayer() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let selected = SelectedTextContext(
            text: "original text",
            isEditable: false,
            isSecure: false,
            applicationName: "Notes"
        )

        let getSelectedTextUseCase = MockGetSelectedTextUseCase()
        getSelectedTextUseCase.result = selected

        let processVoiceCommandUseCase = MockProcessVoiceCommandUseCase()
        processVoiceCommandUseCase.result = VoiceCommandResult(
            processedText: "rewritten",
            action: .replaceSelection
        )

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            getSelectedTextUseCase: getSelectedTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase
        )

        await sut.handleKeyDown()
        await waitUntil { getSelectedTextUseCase.executeCallCount == 1 }

        await sut.handleKeyUp()

        await waitUntil { sut.voiceCommandResultLayer != nil }

        XCTAssertEqual(dependencies.processVoiceCommandUseCase.executeCallCount, 1)
        XCTAssertEqual(dependencies.processVoiceCommandUseCase.receivedSelectedText, "original text")
        XCTAssertEqual(dependencies.processVoiceCommandUseCase.receivedTranscription, dependencies.transcribeAudioUseCase.result)
        XCTAssertEqual(dependencies.textOutputRepository.deliverCalls, [])
        XCTAssertEqual(sut.capsuleState, .hidden)
        XCTAssertEqual(sut.voiceCommandResultLayer?.text, "rewritten")
        XCTAssertEqual(sut.voiceCommandResultLayer?.didCopy, false)

        sut.copyVoiceCommandResultLayerText()
        XCTAssertEqual(dependencies.textOutputRepository.copiedTexts, ["rewritten"])
        XCTAssertEqual(sut.voiceCommandResultLayer?.didCopy, true)
    }

    func testHandleKeyUp_withoutSelection_polishesAndDeliversText() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let getSelectedTextUseCase = MockGetSelectedTextUseCase()
        getSelectedTextUseCase.result = .empty

        let polishTextUseCase = MockPolishTextUseCase()
        polishTextUseCase.result = "polished text"

        let textOutputRepository = MockTextOutputRepository()
        textOutputRepository.deliverResult = .copied

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            textOutputRepository: textOutputRepository,
            polishTextUseCase: polishTextUseCase,
            getSelectedTextUseCase: getSelectedTextUseCase
        )

        var willDeliverCount = 0
        sut.onWillDeliverText = { willDeliverCount += 1 }

        await sut.handleKeyDown()
        await sut.handleKeyUp()

        await waitUntil {
            if case .done = sut.capsuleState {
                return true
            }
            return false
        }

        XCTAssertEqual(dependencies.polishTextUseCase.executeCallCount, 1)
        XCTAssertEqual(dependencies.polishTextUseCase.receivedRawText, dependencies.transcribeAudioUseCase.result)
        XCTAssertEqual(dependencies.polishTextUseCase.receivedContext, dependencies.appContextRepository.context.formatted)
        XCTAssertEqual(dependencies.textOutputRepository.deliverCalls, ["polished text"])
        XCTAssertEqual(willDeliverCount, 1)
        XCTAssertEqual(sut.capsuleState, CapsuleState.done(OutputResult.copied))
        XCTAssertNil(sut.voiceCommandResultLayer)
    }

    func testHandleCancel_duringProcessing_showsCanceledAndCancelsToken() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.beforeReturnDelayNanoseconds = 400_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            transcribeAudioUseCase: transcribeAudioUseCase
        )

        await sut.handleKeyDown()
        await sut.handleKeyUp()

        await waitUntil { transcribeAudioUseCase.receivedCancellationToken != nil }
        sut.handleCancel()

        XCTAssertEqual(sut.capsuleState, .canceled)
        XCTAssertEqual(dependencies.polishTextUseCase.executeCallCount, 0)
        XCTAssertEqual(dependencies.processVoiceCommandUseCase.executeCallCount, 0)
        XCTAssertTrue(transcribeAudioUseCase.receivedCancellationToken?.isCancelled() == true)
    }

    func testDeactivate_stopsMonitoringAndResetsState() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let (sut, dependencies) = makeSUT(apiKeyRepository: apiKeyRepository)

        sut.activate()
        await sut.handleKeyDown()
        XCTAssertEqual(sut.capsuleState, .recording)

        sut.deactivate()

        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount == 1 }

        XCTAssertEqual(dependencies.keyMonitoringRepository.stopCallCount, 1)
        XCTAssertEqual(sut.capsuleState, .hidden)
        XCTAssertNil(sut.voiceCommandResultLayer)
    }

    private func makeSUT(
        permissionRepository: MockPermissionRepository = MockPermissionRepository(),
        apiKeyRepository: MockApiKeyRepository = MockApiKeyRepository(),
        keyMonitoringRepository: MockKeyMonitoringRepository = MockKeyMonitoringRepository(),
        textOutputRepository: MockTextOutputRepository = MockTextOutputRepository(),
        appContextRepository: MockAppContextRepository = MockAppContextRepository(),
        recordingControlUseCase: MockRecordingControlUseCase = MockRecordingControlUseCase(),
        stopRecordingUseCase: MockStopRecordingUseCase = MockStopRecordingUseCase(),
        transcribeAudioUseCase: MockTranscribeAudioUseCase = MockTranscribeAudioUseCase(),
        polishTextUseCase: MockPolishTextUseCase = MockPolishTextUseCase(),
        getSelectedTextUseCase: MockGetSelectedTextUseCase = MockGetSelectedTextUseCase(),
        processVoiceCommandUseCase: MockProcessVoiceCommandUseCase = MockProcessVoiceCommandUseCase(),
        prefetchScheduler: MockPrefetchScheduler = MockPrefetchScheduler()
    ) -> (sut: RecordingState, dependencies: Dependencies) {
        let sut = RecordingState(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            keyMonitoringRepository: keyMonitoringRepository,
            textOutputRepository: textOutputRepository,
            appContextRepository: appContextRepository,
            recordingControlUseCase: recordingControlUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            getSelectedTextUseCase: getSelectedTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase,
            prefetchScheduler: prefetchScheduler,
            prefetchDelay: .milliseconds(0)
        )

        let dependencies = Dependencies(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            keyMonitoringRepository: keyMonitoringRepository,
            textOutputRepository: textOutputRepository,
            appContextRepository: appContextRepository,
            recordingControlUseCase: recordingControlUseCase,
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            getSelectedTextUseCase: getSelectedTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase,
            prefetchScheduler: prefetchScheduler
        )

        return (sut, dependencies)
    }

    struct Dependencies {
        let permissionRepository: MockPermissionRepository
        let apiKeyRepository: MockApiKeyRepository
        let keyMonitoringRepository: MockKeyMonitoringRepository
        let textOutputRepository: MockTextOutputRepository
        let appContextRepository: MockAppContextRepository
        let recordingControlUseCase: MockRecordingControlUseCase
        let stopRecordingUseCase: MockStopRecordingUseCase
        let transcribeAudioUseCase: MockTranscribeAudioUseCase
        let polishTextUseCase: MockPolishTextUseCase
        let getSelectedTextUseCase: MockGetSelectedTextUseCase
        let processVoiceCommandUseCase: MockProcessVoiceCommandUseCase
        let prefetchScheduler: MockPrefetchScheduler
    }
}
