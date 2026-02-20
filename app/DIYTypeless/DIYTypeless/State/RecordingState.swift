import Combine
import Foundation
import os.log

enum CapsuleState: Equatable {
    case hidden
    case recording
    case transcribing
    case streaming(partialText: String)  // Real-time streaming transcription
    case polishing
    case done(OutputResult)
    case error(String)
}

// Simple file logger for debugging
class FileLogger {
    static let shared = FileLogger()
    private let logFile: URL
    private let dateFormatter: DateFormatter

    init() {
        logFile = URL(fileURLWithPath: "/tmp/diytypeless_swift.log")
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Clear previous log
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
        log("=== Log file initialized at /tmp/diytypeless_swift.log ===")
    }

    func log(_ message: String) {
        // Logging disabled for production
        // To enable, uncomment the implementation below
    }

    func getLogPath() -> String {
        return logFile.path
    }
}

@MainActor
final class RecordingState: ObservableObject {
    @Published private(set) var capsuleState: CapsuleState = .hidden

    // Dev build only: Live transcription text for debugging
    @Published private(set) var liveTranscriptionText: String = ""

    var onRequireOnboarding: (() -> Void)?
    var onWillDeliverText: (() -> Void)?

    private let logger = FileLogger.shared

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
        // Cancel any active streaming
        streamingTask?.cancel()
        streamingTask = nil
        if let sessionId = streamingSessionId {
            _ = try? stopStreamingSession(sessionId: sessionId)
            streamingSessionId = nil
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
            liveTranscriptionText = ""
            _ = try? stopRecording()
            // Cancel streaming if active
            streamingTask?.cancel()
            streamingTask = nil
            if let sessionId = streamingSessionId {
                _ = try? stopStreamingSession(sessionId: sessionId)
                streamingSessionId = nil
            }
            capsuleState = .hidden

        case .transcribing, .polishing, .streaming:
            currentGeneration += 1
            isProcessing = false
            capturedContext = nil
            liveTranscriptionText = ""
            // Cancel streaming if active
            streamingTask?.cancel()
            streamingTask = nil
            if let sessionId = streamingSessionId {
                _ = try? stopStreamingSession(sessionId: sessionId)
                streamingSessionId = nil
            }
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

        // Show recording UI with waveform (same as Groq)
        capsuleState = .recording
        isRecording = true
        isProcessing = true
        liveTranscriptionText = ""
        capturedContext = contextDetector.captureContext().formatted

        streamingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                guard let modelDir = LocalAsrManager.shared.modelDirectory?.path else {
                    throw NSError(domain: "RecordingState", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local ASR model not found"])
                }

                // Start streaming session
                let sessionId = try startStreamingSession(modelDir: modelDir, language: nil)
                self.streamingSessionId = sessionId

                // Keep showing waveform while recording
                // NOTE: Removed live transcription polling to eliminate FFI overhead
                // The waveform provides sufficient visual feedback during recording
                self.logger.log("[Swift] Recording with streaming session: \(sessionId)")
                while !Task.isCancelled && self.currentGeneration == gen && self.isRecording {
                    // Just wait, no polling needed
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                self.logger.log("[Swift] Recording ended")

                guard self.currentGeneration == gen, !Task.isCancelled else {
                    _ = try? stopStreamingSession(sessionId: sessionId)
                    self.streamingSessionId = nil
                    return
                }

                // User released key - the UI state is already set to .transcribing by handleKeyUp
                // Now we need to stop the streaming and get the final text

                // Stop streaming and get final text using traditional DispatchQueue
                // (similar to how Groq transcription works for consistent behavior)
                let sessionIdForStop = sessionId
                let geminiKeyForPolish = self.geminiKey
                let contextForPolish = self.capturedContext

                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }

                    // Get final transcription
                    let quickText = getStreamingText(sessionId: sessionIdForStop)
                    let rawText: String
                    do {
                        let finalText = try stopStreamingSession(sessionId: sessionIdForStop)
                        rawText = finalText.isEmpty ? quickText : finalText
                    } catch {
                        rawText = quickText
                    }

                    guard self.currentGeneration == gen else { return }

                    // Show polishing UI
                    DispatchQueue.main.async {
                        guard self.currentGeneration == gen else { return }
                        self.capsuleState = .polishing
                    }

                    // Gemini polishing
                    let outputText: String
                    do {
                        outputText = try polishText(apiKey: geminiKeyForPolish, rawText: rawText, context: contextForPolish)
                    } catch {
                        outputText = rawText
                    }

                    DispatchQueue.main.async {
                        guard self.currentGeneration == gen else { return }
                        self.streamingSessionId = nil
                        self.finishOutput(raw: rawText, polished: outputText)
                    }
                }

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

                let rawText = try transcribeWavBytes(
                    apiKey: groqKey,
                    wavBytes: wavData.bytes,
                    language: nil
                )
                guard self.currentGeneration == gen else { return }

                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.capsuleState = .polishing
                }

                // Gemini polishing
                let outputText: String
                do {
                    outputText = try polishText(apiKey: geminiKey, rawText: rawText, context: capturedContext)
                } catch {
                    outputText = rawText
                }

                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.finishOutput(raw: rawText, polished: outputText)
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
        liveTranscriptionText = ""
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
