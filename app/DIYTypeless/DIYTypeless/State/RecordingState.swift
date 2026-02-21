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

    // For local streaming ASR
    private var streamingSessionId: UInt64?
    private var streamingTask: Task<Void, Never>?

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
        cleanupStreamingSession()
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
            cleanupStreamingSession()
            capsuleState = .hidden

        case .transcribing, .polishing:
            currentGeneration += 1
            isProcessing = false
            capturedContext = nil
            cleanupStreamingSession()
            capsuleState = .hidden

        case .hidden, .done, .error:
            break
        }
    }

    /// Clean up any active streaming session and task
    private func cleanupStreamingSession() {
        streamingTask?.cancel()
        streamingTask = nil
        if let sessionId = streamingSessionId {
            _ = try? stopStreamingSession(sessionId: sessionId)
            streamingSessionId = nil
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

        // For local ASR, start streaming immediately
        // For Groq, just start recording
        switch provider {
        case .local:
            startLocalStreamingRecording()
        case .groq:
            do {
                try startRecording()
                isRecording = true
                capsuleState = .recording
                capturedContext = contextDetector.captureContext().formatted
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    /// Start streaming recording for local ASR
    private func startLocalStreamingRecording() {
        currentGeneration += 1
        let gen = currentGeneration

        capsuleState = .recording
        isRecording = true
        isProcessing = true
        capturedContext = contextDetector.captureContext().formatted

        streamingTask = Task { [weak self] in
            guard let self else { return }

            do {
                let sessionId = try await self.setupStreamingSession()
                self.streamingSessionId = sessionId

                await self.runStreamingRecording(sessionId: sessionId, generation: gen)

                guard self.currentGeneration == gen, !Task.isCancelled else {
                    self.cleanupStreamingSession()
                    return
                }

                await self.finalizeStreamingTranscription(sessionId: sessionId, generation: gen)

            } catch {
                await MainActor.run {
                    guard self.currentGeneration == gen else { return }
                    self.showError(error.localizedDescription)
                    self.isProcessing = false
                    self.isRecording = false
                }
            }

            self.streamingTask = nil
        }
    }

    /// Setup streaming session and return session ID
    private func setupStreamingSession() async throws -> UInt64 {
        guard let modelDir = LocalAsrManager.shared.modelDirectory?.path else {
            throw NSError(domain: "RecordingState", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local ASR model not found"])
        }

        return try startStreamingSession(modelDir: modelDir, language: nil)
    }

    /// Run streaming recording loop until user stops
    private func runStreamingRecording(sessionId: UInt64, generation: Int) async {
        while !Task.isCancelled && self.currentGeneration == generation && self.isRecording {
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
    }

    /// Stop streaming and finalize transcription with polishing
    private func finalizeStreamingTranscription(sessionId: UInt64, generation: Int) async {
        let geminiKeyForPolish = self.geminiKey
        let contextForPolish = self.capturedContext

        let rawText = await stopStreamingAndGetText(sessionId: sessionId)

        guard self.currentGeneration == generation else { return }

        await MainActor.run {
            guard self.currentGeneration == generation else { return }
            self.capsuleState = .polishing
        }

        let outputText = await polishWithFallback(rawText: rawText, apiKey: geminiKeyForPolish, context: contextForPolish)

        await MainActor.run {
            guard self.currentGeneration == generation else { return }
            self.streamingSessionId = nil
            self.finishOutput(raw: rawText, polished: outputText)
        }
    }

    /// Stop streaming session and return text (quick or final)
    private func stopStreamingAndGetText(sessionId: UInt64) async -> String {
        let quickText = getStreamingText(sessionId: sessionId)

        do {
            let finalText = try stopStreamingSession(sessionId: sessionId)
            return finalText.isEmpty ? quickText : finalText
        } catch {
            return quickText
        }
    }

    /// Polish text with fallback to raw text on error
    private func polishWithFallback(rawText: String, apiKey: String, context: String?) async -> String {
        do {
            return try polishText(apiKey: apiKey, rawText: rawText, context: context)
        } catch {
            return rawText
        }
    }

    private func handleKeyUp() {
        guard isRecording else { return }

        let provider = AsrSettings.shared.currentProvider

        switch provider {
        case .local:
            // For local streaming, mark recording as done and immediately switch UI
            isRecording = false
            // Immediately show transcribing UI for smooth transition
            capsuleState = .transcribing
        case .groq:
            // For Groq, stop recording and start transcription
            guard !isProcessing else { return }
            isRecording = false
            isProcessing = true

            currentGeneration += 1
            let gen = currentGeneration

            handleGroqTranscription(gen: gen, groqKey: groqKey, geminiKey: geminiKey, capturedContext: capturedContext)
        }
    }

    /// Handle traditional transcription for Groq
    private func handleGroqTranscription(gen: Int, groqKey: String, geminiKey: String, capturedContext: String?) {
        capsuleState = .transcribing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let wavData = try stopRecording()
                guard self.currentGeneration == gen else { return }

                let rawText = try transcribeWavBytes(apiKey: groqKey, wavBytes: wavData.bytes, language: nil)
                guard self.currentGeneration == gen else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentGeneration == gen else { return }
                    self.capsuleState = .polishing
                }

                let outputText = (try? polishText(apiKey: geminiKey, rawText: rawText, context: capturedContext)) ?? rawText

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentGeneration == gen else { return }
                    self.finishOutput(raw: rawText, polished: outputText)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentGeneration == gen else { return }
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
            guard let self, self.capsuleState == expectedState else { return }
            self.capsuleState = .hidden
        }
    }

    private func refreshKeys() {
        groqKey = (keyStore.loadGroqKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        geminiKey = (keyStore.loadGeminiKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
