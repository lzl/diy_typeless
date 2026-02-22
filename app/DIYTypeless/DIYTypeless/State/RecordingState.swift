import Foundation
import Observation

enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing
    case polishing
    case done(OutputResult)
    case error(String)
}

@MainActor
@Observable
final class RecordingState {
    private(set) var capsuleState: CapsuleState = .hidden

    var onRequireOnboarding: (() -> Void)?
    var onWillDeliverText: (() -> Void)?

    private let permissionManager: PermissionManager
    private let apiKeyRepository: ApiKeyRepository
    private let keyMonitor: KeyMonitor
    private let outputManager: TextOutputManager
    private let transcriptionUseCase: TranscriptionUseCaseProtocol
    private let recordingControlUseCase: RecordingControlUseCaseProtocol
    private let contextDetector = AppContextDetector()

    private var groqKey: String = ""
    private var geminiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    nonisolated(unsafe) private var currentGeneration: Int = 0

    init(
        permissionManager: PermissionManager,
        apiKeyRepository: ApiKeyRepository,
        keyMonitor: KeyMonitor,
        outputManager: TextOutputManager,
        transcriptionUseCase: TranscriptionUseCaseProtocol = TranscriptionPipelineUseCase(),
        recordingControlUseCase: RecordingControlUseCaseProtocol = RecordingControlUseCase()
    ) {
        self.permissionManager = permissionManager
        self.apiKeyRepository = apiKeyRepository
        self.keyMonitor = keyMonitor
        self.outputManager = outputManager
        self.transcriptionUseCase = transcriptionUseCase
        self.recordingControlUseCase = recordingControlUseCase

        keyMonitor.onFnDown = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyDown()
            }
        }
        keyMonitor.onFnUp = { [weak self] in
            Task { @MainActor in
                await self?.handleKeyUp()
            }
        }
    }

    func activate() {
        refreshKeys()
        let status = permissionManager.currentStatus()
        if status.allGranted {
            _ = keyMonitor.start()
        } else {
            keyMonitor.stop()
            onRequireOnboarding?()
        }
    }

    func deactivate() {
        keyMonitor.stop()
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
        case .recording:
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

        let status = permissionManager.currentStatus()
        guard status.allGranted else {
            showError("Permissions required")
            onRequireOnboarding?()
            return
        }

        guard !isRecording, !isProcessing else { return }

        refreshKeys()

        // Check Groq API key
        if groqKey.isEmpty {
            showError("Groq API key required")
            onRequireOnboarding?()
            return
        }

        // Gemini always required (for polishing)
        if geminiKey.isEmpty {
            showError("Gemini API key required")
            onRequireOnboarding?()
            return
        }

        // Warm up TLS connections in background to reduce latency
        Task {
            await recordingControlUseCase.warmupConnections()
        }

        do {
            try await recordingControlUseCase.startRecording()
            isRecording = true
            capsuleState = .recording
            capturedContext = contextDetector.captureContext().formatted
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

        capsuleState = .transcribing

        do {
            let result = try await transcriptionUseCase.execute(
                groqKey: groqKey,
                geminiKey: geminiKey,
                context: capturedContext
            )

            guard currentGeneration == gen else { return }

            capsuleState = .polishing

            // Short delay to show polishing state before completing
            try? await Task.sleep(for: .milliseconds(100))

            guard currentGeneration == gen else { return }

            finishOutput(raw: result.rawText, polished: result.polishedText)
        } catch {
            guard currentGeneration == gen else { return }
            showError(error.localizedDescription)
            isProcessing = false
        }
    }

    private func finishOutput(raw: String, polished: String) {
        onWillDeliverText?()
        let result = outputManager.deliver(text: polished)
        capsuleState = .done(result)
        isProcessing = false
        scheduleHide(after: 1.2, expectedState: .done(result))
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
