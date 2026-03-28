import Foundation
import Observation

public enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case groqKey
    case llmProvider
    case completion

    public var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    public var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

@MainActor
@Observable
public final class OnboardingState {
    public var step: OnboardingStep = .welcome
    public var permissions = PermissionStatus(accessibility: false, microphone: false)
    public private(set) var selectedLLMProvider: ApiProvider = .gemini
    public var groqKey: String = "" {
        didSet {
            if groqKey != oldValue {
                groqValidation = .idle
            }
        }
    }
    public var geminiKey: String = "" {
        didSet {
            if geminiKey != oldValue {
                geminiValidation = .idle
            }
        }
    }
    public var openAIKey: String = "" {
        didSet {
            if openAIKey != oldValue {
                openAIValidation = .idle
            }
        }
    }
    public var groqValidation: ValidationState = .idle
    public var geminiValidation: ValidationState = .idle
    public var openAIValidation: ValidationState = .idle

    public var onCompletion: (() -> Void)?
    public var onRequestRestart: (() -> Void)?

    public var activeLLMValidation: ValidationState {
        validationState(for: selectedLLMProvider)
    }

    public var llmProviderOptions: [ApiProvider] {
        ApiProvider.llmProviders
    }

    public var canProceed: Bool {
        switch step {
        case .welcome:
            return true
        case .microphone:
            return permissions.microphone
        case .accessibility:
            return permissions.accessibility
        case .groqKey:
            return groqValidation.isSuccess
        case .llmProvider:
            return activeLLMValidation.isSuccess
        case .completion:
            return true
        }
    }

    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private let preferredLLMProviderRepository: PreferredLLMProviderRepository
    private let externalLinkRepository: ExternalLinkRepository
    private let validateApiKeyUseCase: ValidateApiKeyUseCaseProtocol
    private var permissionTimer: Timer?
    private var validationTasks: [ApiProvider: Task<Void, Never>] = [:]
    private var revalidationSessionID: Int = 0

    private static let hasCompletedWelcomeKey = "hasCompletedWelcome"

    private var hasCompletedWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasCompletedWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasCompletedWelcomeKey) }
    }

    public init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        preferredLLMProviderRepository: PreferredLLMProviderRepository,
        externalLinkRepository: ExternalLinkRepository,
        validateApiKeyUseCase: ValidateApiKeyUseCaseProtocol
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.preferredLLMProviderRepository = preferredLLMProviderRepository
        self.externalLinkRepository = externalLinkRepository
        self.validateApiKeyUseCase = validateApiKeyUseCase
        refreshPermissions()
        refresh()
    }

    public func shutdown() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        validationTasks.values.forEach { $0.cancel() }
        validationTasks.removeAll()
    }

    public func refresh() {
        let loadedProvider = preferredLLMProviderRepository.loadProvider()
        selectedLLMProvider = loadedProvider.isLLMProvider ? loadedProvider : .gemini
        groqKey = apiKeyRepository.loadKey(for: .groq) ?? ""
        geminiKey = apiKeyRepository.loadKey(for: .gemini) ?? ""
        openAIKey = apiKeyRepository.loadKey(for: .openai) ?? ""
        groqValidation = groqKey.isEmpty ? .idle : .success
        geminiValidation = geminiKey.isEmpty ? .idle : .success
        openAIValidation = openAIKey.isEmpty ? .idle : .success
        refreshPermissions()
        syncStep()
        revalidationSessionID += 1
        revalidateStoredKeys(sessionID: revalidationSessionID)
    }

    private func revalidateStoredKeys(sessionID: Int) {
        revalidateStoredKey(for: .groq, sessionID: sessionID)
        revalidateStoredKey(for: selectedLLMProvider, sessionID: sessionID)
    }

    private func revalidateStoredKey(for provider: ApiProvider, sessionID: Int) {
        let trimmed = keyValue(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                try await validateKeyValue(trimmed, for: provider)
            } catch {
                if !Task.isCancelled,
                   isCurrentRevalidationSession(sessionID),
                   currentKeyMatches(trimmed, provider: provider) {
                    setValidationState(
                        .failure(errorMessage(for: error, provider: provider.displayName)),
                        for: provider
                    )
                }
            }
        }
    }

    public func startPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }

    public func stopPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    public func goNext() {
        if step == .welcome {
            hasCompletedWelcome = true
        }
        if let next = step.next {
            step = next
        }
    }

    public func goBack() {
        if let previous = step.previous {
            step = previous
        }
    }

    public func complete() {
        onCompletion?()
    }

    public func showCompletion() {
        step = .completion
    }

    public func requestRestart() {
        onRequestRestart?()
    }

    public func requestMicrophonePermission() {
        Task {
            _ = await permissionRepository.requestMicrophone()
            await MainActor.run {
                refreshPermissions()
            }
        }
    }

    public func requestAccessibilityPermission() {
        _ = permissionRepository.requestAccessibility()
        refreshPermissions()
    }

    public func openAccessibilitySettings() {
        permissionRepository.openAccessibilitySettings()
    }

    public func openMicrophoneSettings() {
        permissionRepository.openMicrophoneSettings()
    }

    public func openProviderConsole(for provider: ApiProvider) {
        externalLinkRepository.openConsole(for: provider)
    }

    public func selectLLMProvider(_ provider: ApiProvider) {
        guard provider.isLLMProvider else { return }
        guard selectedLLMProvider != provider else { return }

        let shouldPreserveCurrentStep = step == .llmProvider
        selectedLLMProvider = provider
        preferredLLMProviderRepository.saveProvider(provider)
        if !shouldPreserveCurrentStep {
            syncStep()
        }
        revalidationSessionID += 1
        revalidateStoredKeys(sessionID: revalidationSessionID)
    }

    public func validateGroqKey() {
        validateKey(for: .groq)
    }

    public func validateGeminiKey() {
        validateKey(for: .gemini)
    }

    public func validateOpenAIKey() {
        validateKey(for: .openai)
    }

    public func validateActiveLLMKey() {
        validateKey(for: selectedLLMProvider)
    }

    private func syncStep() {
        if !hasCompletedWelcome {
            step = .welcome
            return
        }

        if !permissions.microphone {
            step = .microphone
            return
        }

        if !permissions.accessibility {
            step = .accessibility
            return
        }

        if groqKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            step = .groqKey
            return
        }

        if keyValue(for: selectedLLMProvider).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            step = .llmProvider
            return
        }

        step = .completion
    }

    private func refreshPermissions() {
        permissions = permissionRepository.currentStatus
    }

    private func errorMessage(for error: Error, provider: String) -> String {
        if let validationError = error as? ValidationError {
            return validationError.message
        }
        return "\(provider) validation failed: \(error.localizedDescription)"
    }

    private func validateKey(for provider: ApiProvider) {
        let trimmed = keyValue(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setValidationState(.failure("\(provider.apiKeyPlaceholder) to continue."), for: provider)
            return
        }

        validationTasks[provider]?.cancel()
        setValidationState(.validating, for: provider)

        validationTasks[provider] = Task {
            do {
                try await validateKeyValue(trimmed, for: provider)
                if Task.isCancelled || !currentKeyMatches(trimmed, provider: provider) { return }
                setValidationState(.success, for: provider)
                try? apiKeyRepository.saveKey(trimmed, for: provider)
            } catch {
                if Task.isCancelled || !currentKeyMatches(trimmed, provider: provider) { return }
                setValidationState(.failure(errorMessage(for: error, provider: provider.displayName)), for: provider)
            }
        }
    }

    private func validateKeyValue(_ key: String, for provider: ApiProvider) async throws {
        try await validateApiKeyUseCase.execute(key: key, for: provider)
    }

    private func keyValue(for provider: ApiProvider) -> String {
        switch provider {
        case .groq:
            return groqKey
        case .gemini:
            return geminiKey
        case .openai:
            return openAIKey
        }
    }

    private func currentKeyMatches(_ key: String, provider: ApiProvider) -> Bool {
        keyValue(for: provider).trimmingCharacters(in: .whitespacesAndNewlines) == key
    }

    private func validationState(for provider: ApiProvider) -> ValidationState {
        switch provider {
        case .groq:
            return groqValidation
        case .gemini:
            return geminiValidation
        case .openai:
            return openAIValidation
        }
    }

    private func setValidationState(_ state: ValidationState, for provider: ApiProvider) {
        switch provider {
        case .groq:
            groqValidation = state
        case .gemini:
            geminiValidation = state
        case .openai:
            openAIValidation = state
        }
    }

    private func isCurrentRevalidationSession(_ sessionID: Int) -> Bool {
        revalidationSessionID == sessionID
    }
}
