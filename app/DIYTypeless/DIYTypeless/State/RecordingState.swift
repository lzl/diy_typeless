import Combine
import Foundation

enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing
    case polishing
    case done(OutputResult)
    case error(String)
}

@MainActor
final class RecordingState: ObservableObject {
    @Published private(set) var capsuleState: CapsuleState = .hidden

    var onRequireOnboarding: (() -> Void)?
    var onWillDeliverText: (() -> Void)?

    private let permissionManager: PermissionManager
    private let keyStore: ApiKeyStore
    private let keyMonitor: KeyMonitor
    private let outputManager: TextOutputManager
    private let contextDetector = AppContextDetector()

    private var groqKey: String = ""
    private var geminiKey: String = ""
    private var isRecording = false
    private var isProcessing = false
    private var capturedContext: String?
    nonisolated(unsafe) private var currentGeneration: Int = 0

    init(
        permissionManager: PermissionManager,
        keyStore: ApiKeyStore,
        keyMonitor: KeyMonitor,
        outputManager: TextOutputManager
    ) {
        self.permissionManager = permissionManager
        self.keyStore = keyStore
        self.keyMonitor = keyMonitor
        self.outputManager = outputManager

        keyMonitor.onFnDown = { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }
        keyMonitor.onFnUp = { [weak self] in
            Task { @MainActor in
                self?.handleKeyUp()
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

    private func handleKeyDown() {
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

        // Check current ASR provider dependencies
        let provider = AsrSettings.shared.currentProvider
        switch provider {
        case .groq:
            // Groq requires API key
            if groqKey.isEmpty {
                showError("Groq API key required")
                onRequireOnboarding?()
                return
            }
        case .local:
            // Local ASR requires model to be loaded
            if !LocalAsrManager.shared.isModelLoaded {
                showError("Local ASR model not loaded")
                onRequireOnboarding?()
                return
            }
        }

        // Gemini always required (for polishing)
        if geminiKey.isEmpty {
            showError("Gemini API key required")
            onRequireOnboarding?()
            return
        }

        do {
            try startRecording()
            isRecording = true
            capsuleState = .recording
            capturedContext = contextDetector.captureContext().formatted
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func handleKeyUp() {
        guard isRecording, !isProcessing else { return }
        isRecording = false
        isProcessing = true
        capsuleState = .transcribing

        currentGeneration += 1
        let gen = currentGeneration

        let provider = AsrSettings.shared.currentProvider

        DispatchQueue.global(qos: .userInitiated).async { [weak self, groqKey, geminiKey, capturedContext, provider] in
            guard let self else { return }
            do {
                let wavData = try stopRecording()
                guard self.currentGeneration == gen else { return }

                // Choose transcription method based on provider: pass empty string for local ASR
                let effectiveGroqKey: String
                switch provider {
                case .local:
                    effectiveGroqKey = ""  // Empty string triggers local ASR (if loaded)
                case .groq:
                    effectiveGroqKey = groqKey
                }

                let result = try processWavBytes(
                    groqApiKey: effectiveGroqKey,
                    geminiApiKey: geminiKey,
                    wavBytes: wavData.bytes,
                    language: nil,
                    context: capturedContext
                )
                guard self.currentGeneration == gen else { return }

                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.capsuleState = .polishing
                }

                // Gemini polishing
                let outputText: String
                do {
                    outputText = try polishText(apiKey: geminiKey, rawText: result.rawText, context: capturedContext)
                } catch {
                    outputText = result.rawText
                }

                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.finishOutput(raw: result.rawText, polished: outputText)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.showError(error.localizedDescription)
                    self.isProcessing = false
                }
            }
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
            guard let self else { return }
            if self.capsuleState == expectedState {
                self.capsuleState = .hidden
            }
        }
    }

    private func refreshKeys() {
        groqKey = (keyStore.loadGroqKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        geminiKey = (keyStore.loadGeminiKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
