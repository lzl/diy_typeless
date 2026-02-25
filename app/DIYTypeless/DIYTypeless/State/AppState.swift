import AppKit
import Foundation
import Observation

struct PermissionStatus: Sendable {
    let accessibility: Bool
    let microphone: Bool

    var allGranted: Bool {
        accessibility && microphone
    }
}

@MainActor
@Observable
final class AppState {
    enum Phase: Sendable {
        case onboarding
        case ready
    }

    private static let restartTerminationDelay: TimeInterval = 0.5

    private(set) var phase: Phase = .onboarding
    let onboarding: OnboardingState
    let recording: RecordingState

    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private let keyMonitoringRepository: KeyMonitoringRepository
    private let textOutputRepository: TextOutputRepository

    private var readinessTimer: Timer?
    private var onboardingWindow: OnboardingWindowController?
    private var capsuleWindow: CapsuleWindowController?
    private var isForcedOnboarding = false
    private var hasShownReadyConfirmation = false

    init(
        apiKeyRepository: ApiKeyRepository? = nil,
        permissionRepository: PermissionRepository? = nil,
        keyMonitoringRepository: KeyMonitoringRepository? = nil,
        textOutputRepository: TextOutputRepository? = nil
    ) {
        let repository = apiKeyRepository ?? KeychainApiKeyRepository()
        self.apiKeyRepository = repository
        self.permissionRepository = permissionRepository ?? SystemPermissionRepository()
        self.keyMonitoringRepository = keyMonitoringRepository ?? SystemKeyMonitoringRepository()
        self.textOutputRepository = textOutputRepository ?? SystemTextOutputRepository()

        onboarding = OnboardingState(permissionRepository: self.permissionRepository, apiKeyRepository: repository)
        recording = RecordingState(
            permissionRepository: self.permissionRepository,
            apiKeyRepository: repository,
            keyMonitoringRepository: self.keyMonitoringRepository,
            textOutputRepository: self.textOutputRepository
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
        if let repository = apiKeyRepository as? KeychainApiKeyRepository {
            repository.preloadKeys()
        }
        configureWindows()
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

    private func checkReadiness() -> Bool {
        let status = permissionRepository.currentStatus
        let geminiKey = (apiKeyRepository.loadKey(for: .gemini) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let groqKey = (apiKeyRepository.loadKey(for: .groq) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return status.allGranted && !geminiKey.isEmpty && !groqKey.isEmpty
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.restartTerminationDelay) {
                NSApp.terminate(nil)
            }
        } catch {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
                NSApp.terminate(nil)
            }
        }
    }
}
