import Foundation
import Observation

enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing(progress: Double)
    case polishing(progress: Double)
    case processingCommand(String, progress: Double)  // Shows voice command being processed
    case done(OutputResult)
    case error(String)
}

@MainActor
@Observable
final class RecordingState {
    private(set) var capsuleState: CapsuleState = .hidden

    var onRequireOnboarding: (() -> Void)?
    var onWillDeliverText: (() -> Void)?

    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private var keyMonitoringRepository: KeyMonitoringRepository
    private let textOutputRepository: TextOutputRepository
    private let appContextRepository: AppContextRepository

    // Recording control
    private let recordingControlUseCase: RecordingControlUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol

    // Transcription pipeline
    private let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    private let polishTextUseCase: PolishTextUseCaseProtocol

    // Voice command
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol

    private var groqKey: String = ""
    private var geminiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    private var currentGeneration: Int = 0

    init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        keyMonitoringRepository: KeyMonitoringRepository,
        textOutputRepository: TextOutputRepository,
        appContextRepository: AppContextRepository = DefaultAppContextRepository(),
        // Recording control
        recordingControlUseCase: RecordingControlUseCaseProtocol = RecordingControlUseCaseImpl(),
        stopRecordingUseCase: StopRecordingUseCaseProtocol = StopRecordingUseCaseImpl(),
        // Transcription pipeline
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCaseImpl(),
        polishTextUseCase: PolishTextUseCaseProtocol = PolishTextUseCaseImpl(),
        // Voice command
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol = GetSelectedTextUseCase(),
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol = ProcessVoiceCommandUseCase()
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.keyMonitoringRepository = keyMonitoringRepository
        self.textOutputRepository = textOutputRepository
        self.appContextRepository = appContextRepository
        self.recordingControlUseCase = recordingControlUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.polishTextUseCase = polishTextUseCase
        self.getSelectedTextUseCase = getSelectedTextUseCase
        self.processVoiceCommandUseCase = processVoiceCommandUseCase

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

    func activate() {
        refreshKeys()
        let status = permissionRepository.currentStatus
        if status.allGranted {
            _ = keyMonitoringRepository.start()
        } else {
            keyMonitoringRepository.stop()
            onRequireOnboarding?()
        }
    }

    func deactivate() {
        keyMonitoringRepository.stop()
        if isRecording {
            Task {
                _ = try? await stopRecordingUseCase.execute()
            }
            isRecording = false
        }
        currentGeneration += 1
        isProcessing = false
        capturedContext = nil
        capsuleState = .hidden
    }

    func handleCancel() {
        switch capsuleState {
        case .recording, .processingCommand:
            isRecording = false
            isProcessing = false
            currentGeneration += 1
            capturedContext = nil
            Task {
                _ = try? await stopRecordingUseCase.execute()
            }
            capsuleState = .hidden

        case .transcribing, .polishing:
            currentGeneration += 1
            isProcessing = false
            capturedContext = nil
            capsuleState = .hidden

        case .hidden, .done, .error:
            break
        }
    }

    private func handleKeyDown() async {
        if isProcessing, !isRecording {
            handleCancel()
            return
        }

        let status = permissionRepository.currentStatus
        guard status.allGranted else {
            showError("Permissions required")
            onRequireOnboarding?()
            return
        }

        guard !isRecording, !isProcessing else { return }

        refreshKeys()

        if groqKey.isEmpty {
            showError("Groq API key required")
            onRequireOnboarding?()
            return
        }

        if geminiKey.isEmpty {
            showError("Gemini API key required")
            onRequireOnboarding?()
            return
        }

        Task {
            await recordingControlUseCase.warmupConnections()
        }

        do {
            try await recordingControlUseCase.startRecording()
            isRecording = true
            capsuleState = .recording
            capturedContext = appContextRepository.captureContext().formatted
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func handleKeyUp() async {
        guard isRecording else { return }

        guard !isProcessing else { return }
        isRecording = false
        isProcessing = true

        currentGeneration += 1
        let gen = currentGeneration

        do {
            // Step 1: Get selected text and stop recording
            let selectedTextContext = await getSelectedTextUseCase.execute()
            let wavData = try await stopRecordingUseCase.execute()

            guard currentGeneration == gen else { return }

            // Step 2: Transcribe audio
            capsuleState = .transcribing(progress: 0)
            let rawText = try await transcribeAudioUseCase.execute(
                wavData: wavData,
                apiKey: groqKey,
                language: nil
            )

            guard currentGeneration == gen else { return }

            // Step 3: Determine mode and process
            if shouldUseVoiceCommandMode(selectedTextContext) {
                try await handleVoiceCommandMode(
                    transcription: rawText,
                    selectedText: selectedTextContext.text!,
                    geminiKey: geminiKey,
                    generation: gen
                )
            } else {
                try await handleTranscriptionMode(
                    rawText: rawText,
                    geminiKey: geminiKey,
                    context: capturedContext,
                    generation: gen
                )
            }

        } catch {
            guard currentGeneration == gen else { return }
            showError(error.localizedDescription)
            isProcessing = false
        }
    }

    // MARK: - Business Logic

    private func shouldUseVoiceCommandMode(_ context: SelectedTextContext) -> Bool {
        // Note: isEditable is not required for voice command mode
        // Some apps (like Chrome) may report isEditable=false even when text is selected
        // We only care about: hasSelection and !isSecure
        context.hasSelection && !context.isSecure
    }

    // MARK: - Voice Command Mode

    private func handleVoiceCommandMode(
        transcription: String,
        selectedText: String,
        geminiKey: String,
        generation: Int
    ) async throws {
        capsuleState = .processingCommand(transcription, progress: 0)

        let result = try await processVoiceCommandUseCase.execute(
            transcription: transcription,
            selectedText: selectedText,
            geminiKey: geminiKey
        )

        guard currentGeneration == generation else { return }

        onWillDeliverText?()
        let outputResult = textOutputRepository.deliver(text: result.processedText)

        capsuleState = .done(outputResult)
        isProcessing = false

        scheduleHide(after: 1.2, expectedState: .done(outputResult))
    }

    // MARK: - Transcription Mode (Fallback)

    private func handleTranscriptionMode(
        rawText: String,
        geminiKey: String,
        context: String?,
        generation: Int
    ) async throws {
        capsuleState = .polishing(progress: 0)

        let polishedText = try await polishTextUseCase.execute(
            rawText: rawText,
            apiKey: geminiKey,
            context: context
        )

        guard currentGeneration == generation else { return }

        onWillDeliverText?()
        let outputResult = textOutputRepository.deliver(text: polishedText)

        capsuleState = .done(outputResult)
        isProcessing = false

        scheduleHide(after: 1.2, expectedState: .done(outputResult))
    }

    private func showError(_ message: String) {
        capsuleState = .error(message)
        isRecording = false
        isProcessing = false
        scheduleHide(after: 2.0, expectedState: .error(message))
    }

    private func scheduleHide(after delay: TimeInterval, expectedState: CapsuleState) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.capsuleState == expectedState else { return }
            self.capsuleState = .hidden
        }
    }

    private func refreshKeys() {
        groqKey = (apiKeyRepository.loadKey(for: .groq) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        geminiKey = (apiKeyRepository.loadKey(for: .gemini) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
