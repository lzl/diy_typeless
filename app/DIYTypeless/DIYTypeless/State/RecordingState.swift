import Foundation
import Observation

enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing
    case polishing
    case processingCommand(String)  // Shows voice command being processed
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
    private let transcriptionUseCase: TranscriptionUseCaseProtocol
    private let recordingControlUseCase: RecordingControlUseCaseProtocol

    // New use cases for voice command feature
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    private let processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol

    private let appContextRepository: AppContextRepository

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
        transcriptionUseCase: TranscriptionUseCaseProtocol = TranscriptionPipelineUseCase(),
        recordingControlUseCase: RecordingControlUseCaseProtocol = RecordingControlUseCase(),
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol = GetSelectedTextUseCase(),
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol = ProcessVoiceCommandUseCase(),
        appContextRepository: AppContextRepository = DefaultAppContextRepository()
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.keyMonitoringRepository = keyMonitoringRepository
        self.textOutputRepository = textOutputRepository
        self.transcriptionUseCase = transcriptionUseCase
        self.recordingControlUseCase = recordingControlUseCase
        self.getSelectedTextUseCase = getSelectedTextUseCase
        self.processVoiceCommandUseCase = processVoiceCommandUseCase
        self.appContextRepository = appContextRepository

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
            _ = try? stopRecording()
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
            _ = try? stopRecording()
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

        // Step 1: Get selected text (parallel with stopping recording)
        let selectedTextContext = await getSelectedTextUseCase.execute()

        capsuleState = .transcribing

        do {
            // Step 2: Execute transcription pipeline
            let transcriptionResult = try await transcriptionUseCase.execute(
                groqKey: groqKey,
                geminiKey: geminiKey,
                context: capturedContext
            )

            guard currentGeneration == gen else { return }

            // Step 3: Determine processing mode based on selected text
            if shouldUseVoiceCommandMode(selectedTextContext) {
                // Voice Command Mode
                capsuleState = .processingCommand(transcriptionResult.rawText)

                try await handleVoiceCommandMode(
                    transcription: transcriptionResult.rawText,
                    selectedText: selectedTextContext.text!,
                    geminiKey: geminiKey,
                    generation: gen
                )
            } else {
                // Transcription Mode (Fallback)
                try await handleTranscriptionMode(
                    transcriptionResult: transcriptionResult,
                    generation: gen
                )
            }

        } catch {
            guard currentGeneration == gen else { return }
            showError(error.localizedDescription)
            isProcessing = false
        }
    }

    // MARK: - Business Logic (moved from Entity to ViewModel)

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
        transcriptionResult: TranscriptionResult,
        generation: Int
    ) async throws {
        guard currentGeneration == generation else { return }

        capsuleState = .polishing

        try? await Task.sleep(for: .milliseconds(100))

        guard currentGeneration == generation else { return }

        onWillDeliverText?()
        let outputResult = textOutputRepository.deliver(text: transcriptionResult.polishedText)

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
