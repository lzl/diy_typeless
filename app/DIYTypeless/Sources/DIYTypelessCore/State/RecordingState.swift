import Foundation
import Observation

public enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing(progress: Double)
    case polishing(progress: Double)
    case processingCommand(String, progress: Double)  // Shows voice command being processed
    case canceled
    case done(OutputResult)
    case error(UserFacingError)
}

@MainActor
@Observable
public final class RecordingState {
    public private(set) var capsuleState: CapsuleState = .hidden
    public private(set) var voiceCommandResultLayer: VoiceCommandResultLayerState?

    public var onRequireOnboarding: (() -> Void)?
    public var onWillDeliverText: (() -> Void)?

    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private let preferredLLMProviderRepository: PreferredLLMProviderRepository
    private var keyMonitoringRepository: KeyMonitoringRepository
    private let textOutputRepository: TextOutputRepository
    private let appContextRepository: AppContextRepository

    // Recording control
    private let recordingControlUseCase: RecordingControlUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol

    // Voice command
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    private let pipelineCoordinator: RecordingPipelineCoordinating

    // Prefetch
    private var preselectedContext: SelectedTextContext?
    private var prefetchTask: Task<Void, Never>?
    private var prefetchSessionID: Int = 0
    private let prefetchScheduler: PrefetchScheduler
    private let prefetchDelay: Duration

    private var groqKey: String = ""
    private var llmProvider: ApiProvider = .gemini
    private var llmApiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    private var currentGeneration: Int = 0
    private var processingGeneration: Int?
    private var processingTask: Task<Void, Never>?
    private var processingCancellationToken: CancellationToken?
    private var stopOperationCount: Int = 0
    private var generationsAwaitingStopCompletion: Set<Int> = []
    private let autoHideController: CapsuleStateAutoHideController
    private let stateTransitionGuard = CapsuleStateTransitionGuard()
    private let cancelFeedbackDuration: TimeInterval = 0.8

    public init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        preferredLLMProviderRepository: PreferredLLMProviderRepository,
        keyMonitoringRepository: KeyMonitoringRepository,
        textOutputRepository: TextOutputRepository,
        appContextRepository: AppContextRepository,
        // Recording control
        recordingControlUseCase: RecordingControlUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        // Transcription pipeline
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol,
        polishTextUseCase: PolishTextUseCaseProtocol,
        // Voice command
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol,
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol,
        // Prefetch
        prefetchScheduler: PrefetchScheduler = RealPrefetchScheduler(),
        prefetchDelay: Duration = .milliseconds(300),
        pipelineCoordinator: RecordingPipelineCoordinating? = nil,
        autoHideController: CapsuleStateAutoHideController? = nil
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.preferredLLMProviderRepository = preferredLLMProviderRepository
        self.keyMonitoringRepository = keyMonitoringRepository
        self.textOutputRepository = textOutputRepository
        self.appContextRepository = appContextRepository
        self.recordingControlUseCase = recordingControlUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.getSelectedTextUseCase = getSelectedTextUseCase
        self.pipelineCoordinator = pipelineCoordinator ?? RecordingPipelineCoordinator(
            stopRecordingUseCase: stopRecordingUseCase,
            transcribeAudioUseCase: transcribeAudioUseCase,
            polishTextUseCase: polishTextUseCase,
            processVoiceCommandUseCase: processVoiceCommandUseCase
        )
        self.prefetchScheduler = prefetchScheduler
        self.prefetchDelay = prefetchDelay
        self.autoHideController = autoHideController ?? CapsuleStateAutoHideController()

        keyMonitoringRepository.onFnDown = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyDown()
            }
        }
        keyMonitoringRepository.onFnUp = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyUp()
            }
        }
    }

    public func shutdown() {
        deactivate()
        keyMonitoringRepository.onFnDown = nil
        keyMonitoringRepository.onFnUp = nil
        autoHideController.cancel()
    }

    public func activate() {
        refreshKeys()
        let status = permissionRepository.currentStatus
        if status.allGranted {
            _ = keyMonitoringRepository.start()
        } else {
            keyMonitoringRepository.stop()
            onRequireOnboarding?()
        }
    }

    public func deactivate() {
        keyMonitoringRepository.stop()
        cancelPendingHide()
        cleanupPrefetch()
        cancelProcessingPipeline()
        if isRecording {
            stopRecordingIfNeeded()
            isRecording = false
        }
        currentGeneration += 1
        isProcessing = false
        capturedContext = nil
        voiceCommandResultLayer = nil
        setCapsuleState(.hidden)
    }

    public func handleCancel() {
        cleanupPrefetch()
        cancelProcessingPipeline()
        if voiceCommandResultLayer != nil {
            closeVoiceCommandResultLayer()
            return
        }

        switch capsuleState {
        case .recording:
            if isProcessing {
                currentGeneration += 1
                isProcessing = false
                capturedContext = nil
                setCapsuleState(.canceled)
                scheduleHide(after: cancelFeedbackDuration, expectedState: .canceled)
            } else {
                isRecording = false
                isProcessing = false
                currentGeneration += 1
                capturedContext = nil
                stopRecordingIfNeeded()
                setCapsuleState(.hidden)
            }

        case .processingCommand, .transcribing, .polishing:
            currentGeneration += 1
            isProcessing = false
            capturedContext = nil
            setCapsuleState(.canceled)
            scheduleHide(after: cancelFeedbackDuration, expectedState: .canceled)

        case .hidden, .canceled, .done, .error:
            break
        }
    }

    // MARK: - Key Event Handlers (Internal for Testing)

    public func handleKeyDown() async {
        if isProcessing, !isRecording {
            handleCancel()
            return
        }

        let status = permissionRepository.currentStatus
        guard status.allGranted else {
            showError(.invalidAPIKey)
            onRequireOnboarding?()
            return
        }

        guard !isRecording, !isProcessing, !isStoppingRecording else { return }

        refreshKeys()

        if groqKey.isEmpty {
            showError(.invalidAPIKey)
            onRequireOnboarding?()
            return
        }

        if llmApiKey.isEmpty {
            showError(.invalidAPIKey)
            onRequireOnboarding?()
            return
        }

        Task {
            await recordingControlUseCase.warmupConnections(llmProvider: llmProvider)
        }

        do {
            try await recordingControlUseCase.startRecording()
            isRecording = true
            voiceCommandResultLayer = nil
            setCapsuleState(.recording)
            capturedContext = appContextRepository.captureContext().formatted
            preselectedContext = nil
            prefetchSessionID += 1
            let prefetchSessionID = self.prefetchSessionID

            // Schedule prefetch of selected text after delay
            prefetchTask = prefetchScheduler.schedule(delay: prefetchDelay) { [weak self] in
                guard let self else { return }
                let context = await self.getSelectedTextUseCase.execute()
                guard !Task.isCancelled else { return }
                await self.setPreselectedContext(context, sessionID: prefetchSessionID)
            }
        } catch {
            showError(.unknown(error.localizedDescription))
        }
    }

    public func handleKeyUp() async {
        guard isRecording else { return }

        cancelPrefetchTask()  // Cancel any pending prefetch task, but keep preselectedContext

        guard !isProcessing else { return }
        isRecording = false
        isProcessing = true

        currentGeneration += 1
        let gen = currentGeneration
        let context: SelectedTextContext
        if let preselectedContext {
            context = preselectedContext
        } else {
            context = await getSelectedTextUseCase.execute()
        }
        preselectedContext = nil

        let cancellationToken = CancellationToken()
        processingGeneration = gen
        processingCancellationToken = cancellationToken
        generationsAwaitingStopCompletion.insert(gen)
        beginStopOperation()

        processingTask = Task { [weak self] in
            await self?.runProcessingPipeline(
                generation: gen,
                context: context,
                cancellationToken: cancellationToken
            )
        }
    }

    public func copyVoiceCommandResultLayerText() {
        guard let layer = voiceCommandResultLayer else { return }
        textOutputRepository.copyToClipboard(text: layer.text)
        voiceCommandResultLayer = VoiceCommandResultLayerState(text: layer.text, didCopy: true)
    }

    public func closeVoiceCommandResultLayer() {
        voiceCommandResultLayer = nil
    }

    private func showError(_ error: UserFacingError) {
        setCapsuleState(.error(error))
        isRecording = false
        isProcessing = false
        scheduleHide(after: 2.0, expectedState: .error(error))
    }

    private func scheduleHide(after delay: TimeInterval, expectedState: CapsuleState) {
        autoHideController.schedule(
            after: delay,
            expectedState: expectedState,
            currentState: { [weak self] in self?.capsuleState ?? .hidden },
            onHide: { [weak self] in
                self?.setCapsuleState(.hidden)
            }
        )
    }

    private func refreshKeys() {
        groqKey = (apiKeyRepository.loadKey(for: .groq) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredProvider = preferredLLMProviderRepository.loadProvider()
        llmProvider = preferredProvider.isLLMProvider ? preferredProvider : .gemini
        llmApiKey = (apiKeyRepository.loadKey(for: llmProvider) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cancelPrefetchTask() {
        if let task = prefetchTask {
            prefetchScheduler.cancel(task)
        }
        prefetchTask = nil
    }

    private func cleanupPrefetch() {
        cancelPrefetchTask()
        preselectedContext = nil
    }

    private func cancelProcessingPipeline() {
        processingCancellationToken?.cancel()
        processingCancellationToken = nil
        processingTask?.cancel()
        processingTask = nil
        processingGeneration = nil
    }

    private func cancelPendingHide() {
        autoHideController.cancel()
    }

    private func stopRecordingIfNeeded() {
        guard !isStoppingRecording else { return }
        beginStopOperation()

        Task { [weak self] in
            guard let self else { return }
            defer { self.endStopOperation() }
            _ = try? await self.stopRecordingUseCase.execute()
        }
    }

    private func setPreselectedContext(_ context: SelectedTextContext, sessionID: Int) {
        guard prefetchSessionID == sessionID else { return }
        preselectedContext = context
    }

    private func setCapsuleState(
        _ nextState: CapsuleState,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let previousState = capsuleState
        guard stateTransitionGuard.canTransition(from: previousState, to: nextState) else {
            assertionFailure(
                "Invalid capsule state transition: \(previousState) -> \(nextState)",
                file: file,
                line: line
            )
            return
        }
        capsuleState = nextState
    }

    private func applyPipelineProgress(
        _ progress: RecordingPipelineProgress,
        generation: Int
    ) {
        switch progress {
        case .recordingStopped:
            markStopCompleted(for: generation)
            guard currentGeneration == generation else { return }
        case .transcribing:
            guard currentGeneration == generation else { return }
            setCapsuleState(.transcribing(progress: 0))
        case .polishing:
            guard currentGeneration == generation else { return }
            setCapsuleState(.polishing(progress: 0))
        case .processingCommand(let transcription):
            guard currentGeneration == generation else { return }
            setCapsuleState(.processingCommand(transcription, progress: 0))
        }
    }

    private func runProcessingPipeline(
        generation: Int,
        context: SelectedTextContext,
        cancellationToken: CancellationToken
    ) async {
        defer {
            markStopCompleted(for: generation)
            if processingGeneration == generation {
                processingTask = nil
                processingCancellationToken = nil
                processingGeneration = nil
            }
        }

        do {
            let result = try await pipelineCoordinator.execute(
                request: RecordingPipelineRequest(
                    groqKey: groqKey,
                    llmProvider: llmProvider,
                    llmApiKey: llmApiKey,
                    selectedTextContext: context,
                    appContext: capturedContext,
                    cancellationToken: cancellationToken
                ),
                onProgress: { [weak self] progress in
                    self?.applyPipelineProgress(progress, generation: generation)
                }
            )

            guard currentGeneration == generation else { return }
            switch result {
            case .voiceCommand(let result):
                voiceCommandResultLayer = VoiceCommandResultLayerState(
                    text: result.processedText,
                    didCopy: false
                )
                setCapsuleState(.hidden)
            case .polishedText(let polishedText):
                onWillDeliverText?()
                let outputResult = textOutputRepository.deliver(text: polishedText)
                setCapsuleState(.done(outputResult))
                scheduleHide(after: 1.2, expectedState: .done(outputResult))
            }
            isProcessing = false
        } catch {
            guard currentGeneration == generation else { return }
            if let error = pipelineCoordinator.mapToUserFacingError(error) {
                showError(error)
            } else {
                setCapsuleState(.hidden)
            }
            isProcessing = false
        }
    }

    private var isStoppingRecording: Bool {
        stopOperationCount > 0
    }

    private func beginStopOperation() {
        stopOperationCount += 1
    }

    private func endStopOperation() {
        guard stopOperationCount > 0 else { return }
        stopOperationCount -= 1
    }

    private func markStopCompleted(for generation: Int) {
        guard generationsAwaitingStopCompletion.remove(generation) != nil else { return }
        endStopOperation()
    }
}
