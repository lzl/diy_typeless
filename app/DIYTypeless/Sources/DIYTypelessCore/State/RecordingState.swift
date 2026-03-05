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
    private let prefetchScheduler: PrefetchScheduler
    private let prefetchDelay: Duration

    private var groqKey: String = ""
    private var geminiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    private var currentGeneration: Int = 0
    private var processingGeneration: Int?
    private var processingTask: Task<Void, Never>?
    private var processingCancellationToken: CancellationToken?
    private let autoHideController: CapsuleStateAutoHideController
    private let stateTransitionGuard = CapsuleStateTransitionGuard()
    private let cancelFeedbackDuration: TimeInterval = 0.8

    public init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
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
            Task {
                _ = try? await stopRecordingUseCase.execute()
            }
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
                Task {
                    _ = try? await stopRecordingUseCase.execute()
                }
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

        guard !isRecording, !isProcessing else { return }

        refreshKeys()

        if groqKey.isEmpty {
            showError(.invalidAPIKey)
            onRequireOnboarding?()
            return
        }

        if geminiKey.isEmpty {
            showError(.invalidAPIKey)
            onRequireOnboarding?()
            return
        }

        Task {
            await recordingControlUseCase.warmupConnections()
        }

        do {
            try await recordingControlUseCase.startRecording()
            isRecording = true
            voiceCommandResultLayer = nil
            setCapsuleState(.recording)
            capturedContext = appContextRepository.captureContext().formatted

            // Schedule prefetch of selected text after delay
            prefetchTask = prefetchScheduler.schedule(delay: prefetchDelay) { [weak self] in
                guard let self else { return }
                let context = await self.getSelectedTextUseCase.execute()
                guard !Task.isCancelled else { return }
                await self.setPreselectedContext(context)
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
        let context = preselectedContext ?? .empty
        preselectedContext = nil

        let cancellationToken = CancellationToken()
        processingGeneration = gen
        processingCancellationToken = cancellationToken

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
        geminiKey = (apiKeyRepository.loadKey(for: .gemini) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func setPreselectedContext(_ context: SelectedTextContext) {
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
        guard currentGeneration == generation else { return }
        switch progress {
        case .transcribing:
            setCapsuleState(.transcribing(progress: 0))
        case .polishing:
            setCapsuleState(.polishing(progress: 0))
        case .processingCommand(let transcription):
            setCapsuleState(.processingCommand(transcription, progress: 0))
        }
    }

    private func runProcessingPipeline(
        generation: Int,
        context: SelectedTextContext,
        cancellationToken: CancellationToken
    ) async {
        defer {
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
                    geminiKey: geminiKey,
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
}
