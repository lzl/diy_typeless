import AppKit
import Combine
import Foundation

struct PermissionStatus {
    var accessibility: Bool
    var microphone: Bool

    var allGranted: Bool {
        accessibility && microphone
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case onboarding
        case ready
    }

    /// Delay before terminating app during restart to ensure new instance starts
    private static let restartTerminationDelay: TimeInterval = 0.5

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
    private var hasShownReadyConfirmation = false

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
            self?.onboardingWindow?.hide()
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
        keyStore.preloadKeys()
        configureWindows()
        // Force initial phase setup since phase defaults to .onboarding
        setPhase(checkReadiness() ? .ready : .onboarding, force: true)
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
            guard let self else { return }
            Task { @MainActor [self] in
                self.showOnboarding()
            }
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

    /// Checks if all requirements are met for the app to be ready.
    private func checkReadiness() -> Bool {
        let status = permissionManager.currentStatus()
        let groqKey = (keyStore.loadGroqKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let geminiKey = (keyStore.loadGeminiKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return status.allGranted && !groqKey.isEmpty && !geminiKey.isEmpty
    }

    private func evaluateReadiness() {
        if isForcedOnboarding {
            return
        }
        setPhase(checkReadiness() ? .ready : .onboarding)
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
            recording.activate()
            // Show completion window on first ready state entry
            if !hasShownReadyConfirmation {
                hasShownReadyConfirmation = true
                onboarding.showCompletion()
                onboardingWindow?.show()
            } else {
                onboardingWindow?.hide()
            }
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        do {
            try task.run()
            // Delay exit to ensure new instance starts
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.restartTerminationDelay) {
                NSApp.terminate(nil)
            }
        } catch {
            // Fallback to original method if Process fails
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
                NSApp.terminate(nil)
            }
        }
    }
}
