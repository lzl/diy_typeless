import AppKit
import Combine
import Foundation

struct PermissionStatus {
    var accessibility: Bool
    var inputMonitoring: Bool
    var microphone: Bool

    var allGranted: Bool {
        accessibility && inputMonitoring && microphone
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case onboarding
        case ready
    }

    @Published private(set) var phase: Phase = .onboarding
    let onboarding: OnboardingState
    let recording: RecordingState

    private let permissionManager: PermissionManager
    private let keyStore: ApiKeyStore
    private let keyMonitor: KeyMonitor
    private let outputManager: TextOutputManager

    private var readinessTimer: Timer?
    private var onboardingWindow: OnboardingWindowController?
    private var capsuleWindow: CapsuleWindowController?
    private var isForcedOnboarding = false

    init() {
        permissionManager = PermissionManager()
        keyStore = ApiKeyStore()
        keyMonitor = KeyMonitor()
        outputManager = TextOutputManager()

        onboarding = OnboardingState(permissionManager: permissionManager, keyStore: keyStore)
        recording = RecordingState(
            permissionManager: permissionManager,
            keyStore: keyStore,
            keyMonitor: keyMonitor,
            outputManager: outputManager
        )

        onboarding.onCompletion = { [weak self] in
            self?.isForcedOnboarding = false
            self?.evaluateReadiness()
        }
        onboarding.onRequestRestart = { [weak self] in
            self?.restartApp()
        }
        recording.onRequireOnboarding = { [weak self] in
            self?.isForcedOnboarding = false
            self?.setPhase(.onboarding, force: true)
        }
    }

    func start() {
        uniffiEnsureDiyTypelessCoreInitialized()
        configureWindows()
        evaluateReadiness()
        startReadinessTimer()
        observeShowSettings()
    }

    func showOnboarding() {
        isForcedOnboarding = true
        setPhase(.onboarding, force: true)
    }

    private func observeShowSettings() {
        NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showOnboarding()
        }
    }

    private func configureWindows() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(state: onboarding)
            onboardingWindow?.onClose = { [weak self] in
                guard let self else { return }
                if self.isForcedOnboarding {
                    self.isForcedOnboarding = false
                    self.evaluateReadiness()
                }
            }
        }
        if capsuleWindow == nil {
            capsuleWindow = CapsuleWindowController(state: recording)
        }
    }

    private func startReadinessTimer() {
        readinessTimer?.invalidate()
        readinessTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.evaluateReadiness()
            }
        }
    }

    private func evaluateReadiness() {
        if isForcedOnboarding {
            return
        }

        let status = permissionManager.currentStatus()
        let groqKey = (keyStore.loadGroqKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let geminiKey = (keyStore.loadGeminiKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isReady = status.allGranted && !groqKey.isEmpty && !geminiKey.isEmpty
        setPhase(isReady ? .ready : .onboarding)
    }

    private func setPhase(_ newPhase: Phase, force: Bool = false) {
        if !force, newPhase == phase {
            return
        }

        phase = newPhase
        switch newPhase {
        case .onboarding:
            recording.deactivate()
            onboarding.refresh()
            onboarding.startPolling()
            onboardingWindow?.show()
        case .ready:
            onboarding.stopPolling()
            onboardingWindow?.hide()
            recording.activate()
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            NSApp.terminate(nil)
        }
    }
}
