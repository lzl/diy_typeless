import AppKit
import Foundation
import Observation
import DIYTypelessCore

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
    private let preferredLLMProviderRepository: PreferredLLMProviderRepository
    private let keyMonitoringRepository: KeyMonitoringRepository
    private let textOutputRepository: TextOutputRepository

    private var readinessTimer: Timer?
    private var showSettingsObserver: NSObjectProtocol?
    private var willTerminateObserver: NSObjectProtocol?
    private var onboardingWindow: OnboardingWindowController?
    private var capsuleWindow: CapsuleWindowController?
    private var isForcedOnboarding = false
    private var hasShownReadyConfirmation = false
    private var hasStopped = false

    init(
        apiKeyRepository: ApiKeyRepository? = nil,
        permissionRepository: PermissionRepository? = nil,
        keyMonitoringRepository: KeyMonitoringRepository? = nil,
        textOutputRepository: TextOutputRepository? = nil,
        externalLinkRepository: ExternalLinkRepository? = nil,
        validateApiKeyUseCase: ValidateApiKeyUseCaseProtocol? = nil,
        appContextRepository: AppContextRepository? = nil,
        recordingControlUseCase: RecordingControlUseCaseProtocol? = nil,
        stopRecordingUseCase: StopRecordingUseCaseProtocol? = nil,
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol? = nil,
        polishTextUseCase: PolishTextUseCaseProtocol? = nil,
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol? = nil,
        processVoiceCommandUseCase: ProcessVoiceCommandUseCaseProtocol? = nil
    ) {
        configureCoreFFIRuntimeIfNeeded()

        let repository = apiKeyRepository ?? KeychainApiKeyRepository()
        let preferredLLMProviderRepository = UserDefaultsPreferredLLMProviderRepository()
        self.apiKeyRepository = repository
        self.preferredLLMProviderRepository = preferredLLMProviderRepository
        self.permissionRepository = permissionRepository ?? SystemPermissionRepository()
        self.keyMonitoringRepository = keyMonitoringRepository ?? SystemKeyMonitoringRepository()
        self.textOutputRepository = textOutputRepository ?? SystemTextOutputRepository()
        let resolvedExternalLinkRepository = externalLinkRepository ?? NSWorkspaceExternalLinkRepository()
        let resolvedValidateApiKeyUseCase = validateApiKeyUseCase ?? ValidateApiKeyUseCase(
            groqRepository: GroqApiKeyValidationRepository(),
            geminiRepository: GeminiApiKeyValidationRepository(),
            openAIRepository: OpenAIApiKeyValidationRepository()
        )
        let resolvedAppContextRepository = appContextRepository ?? DefaultAppContextRepository()
        let resolvedRecordingControlUseCase = recordingControlUseCase ?? RecordingControlUseCaseImpl()
        let resolvedStopRecordingUseCase = stopRecordingUseCase ?? StopRecordingUseCaseImpl()
        let resolvedTranscribeAudioUseCase = transcribeAudioUseCase ?? TranscribeAudioUseCaseImpl()
        let resolvedPolishTextUseCase = polishTextUseCase ?? PolishTextUseCaseImpl()
        let resolvedGetSelectedTextUseCase = getSelectedTextUseCase ?? GetSelectedTextUseCase(
            repository: AccessibilitySelectedTextRepository()
        )
        let resolvedProcessVoiceCommandUseCase = processVoiceCommandUseCase
            ?? ProcessVoiceCommandUseCaseImpl(llmRepository: GeminiLLMRepository())

        onboarding = OnboardingState(
            permissionRepository: self.permissionRepository,
            apiKeyRepository: repository,
            preferredLLMProviderRepository: preferredLLMProviderRepository,
            externalLinkRepository: resolvedExternalLinkRepository,
            validateApiKeyUseCase: resolvedValidateApiKeyUseCase
        )
        recording = RecordingState(
            permissionRepository: self.permissionRepository,
            apiKeyRepository: repository,
            preferredLLMProviderRepository: preferredLLMProviderRepository,
            keyMonitoringRepository: self.keyMonitoringRepository,
            textOutputRepository: self.textOutputRepository,
            appContextRepository: resolvedAppContextRepository,
            recordingControlUseCase: resolvedRecordingControlUseCase,
            stopRecordingUseCase: resolvedStopRecordingUseCase,
            transcribeAudioUseCase: resolvedTranscribeAudioUseCase,
            polishTextUseCase: resolvedPolishTextUseCase,
            getSelectedTextUseCase: resolvedGetSelectedTextUseCase,
            processVoiceCommandUseCase: resolvedProcessVoiceCommandUseCase
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

    func stop() {
        guard !hasStopped else { return }
        hasStopped = true
        readinessTimer?.invalidate()
        readinessTimer = nil
        if let showSettingsObserver {
            NotificationCenter.default.removeObserver(showSettingsObserver)
            self.showSettingsObserver = nil
        }
        if let willTerminateObserver {
            NotificationCenter.default.removeObserver(willTerminateObserver)
            self.willTerminateObserver = nil
        }
        onboarding.shutdown()
        recording.shutdown()
    }

    func start() {
        uniffiEnsureDiyTypelessCoreInitialized()
        // Skip Keychain preload in test environment to avoid auth prompts
        if ProcessInfo.processInfo.environment["SKIP_KEYCHAIN_PRELOAD"] == nil,
           let repository = apiKeyRepository as? KeychainApiKeyRepository {
            repository.preloadKeys()
        }
        configureWindows()
        setPhase(checkReadiness() ? .ready : .onboarding, force: true)
        startReadinessTimer()
        observeShowSettings()
        observeAppTermination()
    }

    func showOnboarding() {
        isForcedOnboarding = true
        setPhase(.onboarding, force: true)
    }

    private func observeShowSettings() {
        if let showSettingsObserver {
            NotificationCenter.default.removeObserver(showSettingsObserver)
        }
        showSettingsObserver = NotificationCenter.default.addObserver(
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

    private func observeAppTermination() {
        if let willTerminateObserver {
            NotificationCenter.default.removeObserver(willTerminateObserver)
        }
        willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    private func configureWindows() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(state: onboarding, recording: recording)
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
        let llmProvider = preferredLLMProviderRepository.loadProvider()
        let resolvedLLMProvider = llmProvider.isLLMProvider ? llmProvider : .gemini
        let llmKey = (apiKeyRepository.loadKey(for: resolvedLLMProvider) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let groqKey = (apiKeyRepository.loadKey(for: .groq) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return status.allGranted && !llmKey.isEmpty && !groqKey.isEmpty
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
        stop()
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
