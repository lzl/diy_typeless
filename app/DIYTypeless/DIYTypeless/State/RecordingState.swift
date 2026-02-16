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

    private var chunkTimer: DispatchSourceTimer?
    private let chunkQueue = DispatchQueue(label: "com.diytypeless.chunks")
    private var partialTranscripts: [(index: Int, text: String)] = []
    private var nextChunkIndex: Int = 0
    private var chunkGroup = DispatchGroup()

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
        stopChunkTimer()
        resetChunkState()
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
            stopChunkTimer()
            resetChunkState()
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
        guard !groqKey.isEmpty, !geminiKey.isEmpty else {
            showError("API keys required")
            onRequireOnboarding?()
            return
        }

        do {
            try startRecording()
            isRecording = true
            capsuleState = .recording
            capturedContext = contextDetector.captureContext().formatted
            startChunkTimer()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func handleKeyUp() {
        guard isRecording, !isProcessing else { return }
        isRecording = false
        isProcessing = true
        capsuleState = .transcribing

        stopChunkTimer()

        currentGeneration += 1
        let gen = currentGeneration

        DispatchQueue.global(qos: .userInitiated).async { [weak self, groqKey, geminiKey, capturedContext] in
            guard let self else { return }
            do {
                let wavData = try stopRecording()
                guard self.currentGeneration == gen else { return }

                // Transcribe remaining audio (tail chunk) if non-empty
                if !wavData.bytes.isEmpty {
                    let chunkIndex = self.chunkQueue.sync { self.nextChunkIndex }
                    self.chunkQueue.sync { self.nextChunkIndex += 1 }
                    self.chunkGroup.enter()
                    let tailText = try transcribeWavBytes(
                        apiKey: groqKey,
                        wavBytes: wavData.bytes,
                        language: nil
                    )
                    self.chunkQueue.sync {
                        self.partialTranscripts.append((index: chunkIndex, text: tailText))
                    }
                    self.chunkGroup.leave()
                }

                guard self.currentGeneration == gen else { return }

                // Wait for all in-flight chunks to complete
                self.chunkGroup.wait()
                guard self.currentGeneration == gen else { return }

                let rawText = self.chunkQueue.sync {
                    self.partialTranscripts
                        .sorted { $0.index < $1.index }
                        .map(\.text)
                        .joined(separator: " ")
                }

                guard !rawText.isEmpty else {
                    DispatchQueue.main.async {
                        guard self.currentGeneration == gen else { return }
                        self.showError("No audio captured")
                        self.isProcessing = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    guard self.currentGeneration == gen else { return }
                    self.capsuleState = .polishing
                }

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

    // MARK: - Chunk Timer

    private func startChunkTimer() {
        resetChunkState()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + 2, repeating: 2)
        let gen = currentGeneration
        let groqKey = groqKey
        timer.setEventHandler { [weak self] in
            guard let self, self.currentGeneration == gen else { return }
            do {
                guard let wavData = try takeChunk() else { return }
                guard self.currentGeneration == gen else { return }

                let chunkIndex = self.chunkQueue.sync { () -> Int in
                    let idx = self.nextChunkIndex
                    self.nextChunkIndex += 1
                    return idx
                }
                self.chunkGroup.enter()

                let text = try transcribeWavBytes(
                    apiKey: groqKey,
                    wavBytes: wavData.bytes,
                    language: nil
                )
                guard self.currentGeneration == gen else {
                    self.chunkGroup.leave()
                    return
                }

                self.chunkQueue.sync {
                    self.partialTranscripts.append((index: chunkIndex, text: text))
                }
                self.chunkGroup.leave()
            } catch {
                // Chunk transcription failed — log but continue; remaining audio
                // will still be processed on key-up.
            }
        }
        timer.resume()
        chunkTimer = timer
    }

    private func stopChunkTimer() {
        chunkTimer?.cancel()
        chunkTimer = nil
    }

    private func resetChunkState() {
        partialTranscripts = []
        nextChunkIndex = 0
        chunkGroup = DispatchGroup()
    }
}
