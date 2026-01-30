import Foundation
import SwiftUI

enum RecordingStatus: String {
    case idle = "Idle"
    case recording = "Recording"
    case transcribing = "Transcribing"
    case polishing = "Polishing"
    case done = "Done"
    case error = "Error"
}

struct PermissionStatus {
    var accessibility: Bool
    var inputMonitoring: Bool
    var microphone: Bool

    var allGranted: Bool {
        accessibility && inputMonitoring && microphone
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var permissionStatus = PermissionStatus(accessibility: false, inputMonitoring: false, microphone: false)
    @Published var status: RecordingStatus = .idle
    @Published var statusMessage: String = "Ready"
    @Published var lastOutput: String = ""

    @Published var groqApiKey: String = ""
    @Published var geminiApiKey: String = ""

    private let permissionManager = PermissionManager()
    private let keyMonitor = KeyMonitor()
    private let overlayController = StatusOverlayController()
    private let outputManager = TextOutputManager()
    private let keyStore = ApiKeyStore()

    private var isRecording = false
    private var isProcessing = false

    init() {
        groqApiKey = keyStore.loadGroqKey() ?? ""
        geminiApiKey = keyStore.loadGeminiKey() ?? ""

        keyMonitor.onRightOptionDown = { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }
        keyMonitor.onRightOptionUp = { [weak self] in
            Task { @MainActor in
                self?.handleKeyUp()
            }
        }
    }

    func start() {
        uniffiEnsureDiyTypelessCoreInitialized()
        refreshPermissions()
        _ = keyMonitor.start()
        updateStatus(.idle, message: "Hold Right Option to talk")
    }

    func refreshPermissions() {
        permissionStatus = permissionManager.currentStatus()
        if permissionStatus.allGranted {
            _ = keyMonitor.start()
        } else {
            keyMonitor.stop()
        }
    }

    func requestPermissions() {
        _ = permissionManager.requestAccessibility()
        _ = permissionManager.requestInputMonitoring()
        permissionManager.requestMicrophone { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPermissions()
            }
        }
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissionManager.openInputMonitoringSettings()
    }

    func openMicrophoneSettings() {
        permissionManager.openMicrophoneSettings()
    }

    func saveApiKeys() {
        if !groqApiKey.isEmpty {
            keyStore.saveGroqKey(groqApiKey)
        }
        if !geminiApiKey.isEmpty {
            keyStore.saveGeminiKey(geminiApiKey)
        }
    }

    private func handleKeyDown() {
        guard permissionStatus.allGranted else {
            updateStatus(.error, message: "Permissions required")
            return
        }
        guard !isRecording && !isProcessing else { return }
        guard !groqApiKey.isEmpty, !geminiApiKey.isEmpty else {
            updateStatus(.error, message: "Set API keys first")
            return
        }

        do {
            try startRecording()
            isRecording = true
            updateStatus(.recording, message: "Recording...")
        } catch {
            updateStatus(.error, message: error.localizedDescription)
        }
    }

    private func handleKeyUp() {
        guard isRecording, !isProcessing else { return }
        isRecording = false
        isProcessing = true
        updateStatus(.transcribing, message: "Transcribing...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self, groqApiKey, geminiApiKey] in
            do {
                let wavData = try stopRecording()
                let rawText = try transcribeWavBytes(
                    apiKey: groqApiKey,
                    wavBytes: wavData.bytes,
                    language: nil
                )

                DispatchQueue.main.async {
                    self?.updateStatus(.polishing, message: "Polishing...")
                }

                let polished = try polishText(apiKey: geminiApiKey, rawText: rawText)
                DispatchQueue.main.async {
                    self?.finishOutput(raw: rawText, polished: polished)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.updateStatus(.error, message: error.localizedDescription)
                    self?.isProcessing = false
                }
            }
        }
    }

    private func finishOutput(raw: String, polished: String) {
        lastOutput = polished
        let result = outputManager.deliver(text: polished)
        switch result {
        case .pasted:
            updateStatus(.done, message: "Pasted into active field")
        case .copied:
            updateStatus(.done, message: "Copied to clipboard")
        }

        isProcessing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.updateStatus(.idle, message: "Hold Right Option to talk")
        }
    }

    private func updateStatus(_ newStatus: RecordingStatus, message: String) {
        status = newStatus
        statusMessage = message
        overlayController.show(status: newStatus, message: message)
    }
}

