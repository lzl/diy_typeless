import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
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

    func testRepeatedSameError_doesNotHideEarlyFromStaleTimer() async {
        let permissionRepository = MockPermissionRepository(
            currentStatus: PermissionStatus(accessibility: false, microphone: false)
        )
        let autoHideScheduler = ManualAutoHideScheduler()
        let autoHideController = CapsuleStateAutoHideController(
            scheduleWork: autoHideScheduler.schedule(delay:workItem:)
        )
        let (sut, _) = makeSUT(
            permissionRepository: permissionRepository,
            autoHideController: autoHideController
        )

        await sut.handleKeyDown()
        guard case .error = sut.capsuleState else {
            return XCTFail("Expected first state to be .error")
        }

        await sut.handleKeyDown()
        guard case .error = sut.capsuleState else {
            return XCTFail("Expected second state to be .error")
        }

        autoHideScheduler.runNext()
        guard case .error = sut.capsuleState else {
            return XCTFail("Expected stale timer not to hide the second error early")
        }

        autoHideScheduler.runNext()
        XCTAssertEqual(sut.capsuleState, .hidden)
    }

    func testShutdown_afterActivate_stopsKeyMonitoring() async {
        let keyMonitoringRepository = MockKeyMonitoringRepository()
        let sut = makeSUT(
            keyMonitoringRepository: keyMonitoringRepository
        ).sut

        sut.activate()
        XCTAssertEqual(keyMonitoringRepository.startCallCount, 1)
        XCTAssertEqual(keyMonitoringRepository.stopCallCount, 0)

        sut.shutdown()
        await Task.yield()

        XCTAssertEqual(keyMonitoringRepository.stopCallCount, 1)
    }

    func testHandleCancel_immediatelyAfterKeyUp_doesNotTriggerDuplicateStopRecording() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.beforeReturnDelayNanoseconds = 300_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            transcribeAudioUseCase: transcribeAudioUseCase
        )

        await sut.handleKeyDown()
        await sut.handleKeyUp()
        sut.handleCancel()

        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount >= 1 }

        XCTAssertEqual(dependencies.stopRecordingUseCase.executeCallCount, 1)
        XCTAssertEqual(dependencies.textOutputRepository.deliverCalls, [])
    }

    func testDeactivate_immediatelyAfterKeyUp_stillStopsRecording() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.beforeReturnDelayNanoseconds = 300_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            transcribeAudioUseCase: transcribeAudioUseCase
        )

        await sut.handleKeyDown()
        await sut.handleKeyUp()
        sut.deactivate()

        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount >= 1 }
        XCTAssertEqual(dependencies.stopRecordingUseCase.executeCallCount, 1)
        XCTAssertEqual(sut.capsuleState, .hidden)
        XCTAssertEqual(dependencies.textOutputRepository.deliverCalls, [])
    }

    func testHandleCancel_whileStopInFlight_blocksImmediateRestartUntilStopCompletes() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let stopRecordingUseCase = MockStopRecordingUseCase()
        stopRecordingUseCase.beforeReturnDelayNanoseconds = 300_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            stopRecordingUseCase: stopRecordingUseCase
        )

        await sut.handleKeyDown()
        sut.handleCancel()
        await sut.handleKeyDown()

        XCTAssertEqual(
            dependencies.recordingControlUseCase.startRecordingCallCount,
            1,
            "Recording restart should be blocked while previous stop is still running"
        )

        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount == 1 }
        await waitUntil { stopRecordingUseCase.completedCallCount == 1 }
        await waitUntil { sut.capsuleState == .hidden }

        for _ in 0..<5 where dependencies.recordingControlUseCase.startRecordingCallCount < 2 {
            await sut.handleKeyDown()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(dependencies.recordingControlUseCase.startRecordingCallCount, 2)
    }

    func testDeactivate_whileStopInFlight_blocksImmediateRestartUntilStopCompletes() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let stopRecordingUseCase = MockStopRecordingUseCase()
        stopRecordingUseCase.beforeReturnDelayNanoseconds = 300_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            stopRecordingUseCase: stopRecordingUseCase
        )

        await sut.handleKeyDown()
        sut.deactivate()
        await sut.handleKeyDown()

        XCTAssertEqual(
            dependencies.recordingControlUseCase.startRecordingCallCount,
            1,
            "Recording restart should be blocked while deactivate-triggered stop is running"
        )

        await waitUntil { stopRecordingUseCase.completedCallCount == 1 }
        for _ in 0..<5 where dependencies.recordingControlUseCase.startRecordingCallCount < 2 {
            await sut.handleKeyDown()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(dependencies.recordingControlUseCase.startRecordingCallCount, 2)
    }

    func testRapidRepeatedKeyDownWhileRecording_startsRecordingOnlyOnce() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let (sut, dependencies) = makeSUT(apiKeyRepository: apiKeyRepository)

        await sut.handleKeyDown()
        for _ in 0..<10 {
            await sut.handleKeyDown()
        }

        XCTAssertEqual(dependencies.recordingControlUseCase.startRecordingCallCount, 1)
        XCTAssertEqual(sut.capsuleState, .recording)
    }

    func testRapidRepeatedKeyUpWhileProcessing_startsPipelineOnlyOnce() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let transcribeAudioUseCase = MockTranscribeAudioUseCase()
        transcribeAudioUseCase.beforeReturnDelayNanoseconds = 200_000_000

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            transcribeAudioUseCase: transcribeAudioUseCase
        )

        await sut.handleKeyDown()
        await sut.handleKeyUp()
        for _ in 0..<10 {
            await sut.handleKeyUp()
        }

        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount >= 1 }
        XCTAssertEqual(dependencies.stopRecordingUseCase.executeCallCount, 1)
        XCTAssertEqual(dependencies.transcribeAudioUseCase.executeCallCount, 1)
    }

    func testCanceledPrefetch_doesNotLeakSelectedContextIntoNextSession() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq"
        apiKeyRepository.keys[.gemini] = "gemini"

        let prefetchScheduler = MockPrefetchScheduler()
        prefetchScheduler.shouldRunImmediately = false

        let getSelectedTextUseCase = MockGetSelectedTextUseCase()
        getSelectedTextUseCase.result = SelectedTextContext(
            text: "stale selection",
            isEditable: false,
            isSecure: false,
            applicationName: "Notes"
        )

        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            getSelectedTextUseCase: getSelectedTextUseCase,
            prefetchScheduler: prefetchScheduler
        )

        await sut.handleKeyDown()
        sut.handleCancel()
        await waitUntil { dependencies.stopRecordingUseCase.executeCallCount == 1 }

        await prefetchScheduler.runScheduledOperations()
        getSelectedTextUseCase.result = .empty

        await sut.handleKeyDown()
        await sut.handleKeyUp()
        await waitUntil {
            dependencies.polishTextUseCase.executeCallCount > 0
                || dependencies.processVoiceCommandUseCase.executeCallCount > 0
        }

        XCTAssertEqual(
            dependencies.processVoiceCommandUseCase.executeCallCount,
            0,
            "Stale canceled prefetch must not force voice-command path in next session"
        )
        XCTAssertEqual(dependencies.polishTextUseCase.executeCallCount, 1)
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
        prefetchScheduler: MockPrefetchScheduler = MockPrefetchScheduler(),
        autoHideController: CapsuleStateAutoHideController? = nil
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
            prefetchDelay: .milliseconds(0),
            autoHideController: autoHideController
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

@MainActor
private final class ManualAutoHideScheduler {
    private var workItems: [DispatchWorkItem] = []

    func schedule(delay: TimeInterval, workItem: DispatchWorkItem) {
        _ = delay
        workItems.append(workItem)
    }

    func runNext() {
        guard !workItems.isEmpty else { return }
        let workItem = workItems.removeFirst()
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
