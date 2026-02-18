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

// MARK: - Chunk Manager (Thread-safe)

nonisolated final class ChunkManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.diytypeless.chunks")
    private var _partialTranscripts: [(index: Int, text: String)] = []
    private var _nextChunkIndex: Int = 0
    private var _group = DispatchGroup()

    var partialTranscripts: [(index: Int, text: String)] {
        queue.sync { _partialTranscripts }
    }

    func getAndIncrementIndex() -> Int {
        queue.sync {
            let idx = _nextChunkIndex
            _nextChunkIndex += 1
            return idx
        }
    }

    func appendTranscript(_ transcript: (index: Int, text: String)) {
        queue.sync {
            _partialTranscripts.append(transcript)
        }
    }

    func reset() {
        queue.sync {
            _partialTranscripts = []
            _nextChunkIndex = 0
            _group = DispatchGroup()
        }
    }

    func enter() {
        let g = queue.sync { _group }
        g.enter()
    }

    func leave() {
        let g = queue.sync { _group }
        g.leave()
    }

    func wait() {
        let g = queue.sync { _group }
        g.wait()
    }
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
    private let chunkManager = ChunkManager()

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

        // Capture chunk manager for detached task
        let chunkManager = self.chunkManager

        Task.detached { [weak self, groqKey, geminiKey, capturedContext, gen] in
            do {
                // Export full recording BEFORE stopping (must be called before stopRecording)
                #if DEBUG
                let fullWavData: WavData? = try exportFullRecording()
                #else
                let fullWavData: WavData? = nil
                #endif

                let wavData = try stopRecording()
                let cancelled1 = await MainActor.run { self?.currentGeneration != gen }
                guard !cancelled1 else { return }

                // Transcribe remaining audio (tail chunk) if non-empty
                if !wavData.bytes.isEmpty {
                    let chunkIndex = chunkManager.getAndIncrementIndex()
                    chunkManager.enter()
                    let tailText = try transcribeWavBytes(
                        apiKey: groqKey,
                        wavBytes: wavData.bytes,
                        language: nil
                    )
                    chunkManager.appendTranscript((index: chunkIndex, text: tailText))
                    chunkManager.leave()
                }

                let cancelled2 = await MainActor.run { self?.currentGeneration != gen }
                guard !cancelled2 else { return }

                // Wait for all in-flight chunks to complete
                chunkManager.wait()
                let cancelled3 = await MainActor.run { self?.currentGeneration != gen }
                guard !cancelled3 else { return }

                let rawText = chunkManager.partialTranscripts
                    .sorted { $0.index < $1.index }
                    .map(\.text)
                    .joined(separator: " ")

                guard !rawText.isEmpty else {
                    await MainActor.run { [weak self] in
                        guard let self, currentGeneration == gen else { return }
                        self.showError("No audio captured")
                        self.isProcessing = false
                    }
                    return
                }

                await MainActor.run { [weak self] in
                    guard let self, currentGeneration == gen else { return }
                    self.capsuleState = .polishing
                }

                let outputText: String
                do {
                    outputText = try polishText(apiKey: geminiKey, rawText: rawText, context: capturedContext)
                } catch {
                    outputText = rawText
                }

                // Save artifacts before finishing output (Debug only)
                #if DEBUG
                if let fullWav = fullWavData {
                    await MainActor.run { [weak self] in
                        self?.saveArtifacts(wavData: fullWav, rawText: rawText, polishedText: outputText)
                    }
                }
                #endif

                await MainActor.run { [weak self] in
                    guard let self, currentGeneration == gen else { return }
                    self.finishOutput(raw: rawText, polished: outputText)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, currentGeneration == gen else { return }
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
        let chunkManager = self.chunkManager
        timer.setEventHandler { [weak self] in
            guard let self, self.currentGeneration == gen else { return }
            do {
                guard let wavData = try takeChunk() else { return }
                guard self.currentGeneration == gen else { return }

                let chunkIndex = chunkManager.getAndIncrementIndex()
                chunkManager.enter()

                let text = try transcribeWavBytes(
                    apiKey: groqKey,
                    wavBytes: wavData.bytes,
                    language: nil
                )
                guard self.currentGeneration == gen else {
                    chunkManager.leave()
                    return
                }

                chunkManager.appendTranscript((index: chunkIndex, text: text))
                chunkManager.leave()
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
        chunkManager.reset()
    }

    // MARK: - Save Artifacts (Debug only)

    private func saveArtifacts(wavData: WavData, rawText: String, polishedText: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let recordingsDir = homeDir.appendingPathComponent("diy_typeless_recordings")

        do {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create recordings directory: \(error)")
            return
        }

        let basePath = recordingsDir.appendingPathComponent("recording_\(timestamp)")

        // Save WAV
        let wavPath = basePath.appendingPathExtension("wav")
        do {
            try wavData.bytes.write(to: wavPath)
        } catch {
            print("Failed to save WAV: \(error)")
        }

        // Save raw text
        let rawPath = basePath.appendingPathExtension("txt")
        do {
            try rawText.write(to: rawPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save raw text: \(error)")
        }

        // Save polished text
        let polishedPath = basePath.path + "_polished.txt"
        do {
            try polishedText.write(toFile: polishedPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save polished text: \(error)")
        }
    }
}
