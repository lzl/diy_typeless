import Foundation
import Observation

public enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case groqKey
    case geminiKey
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
    public var groqValidation: ValidationState = .idle
    public var geminiValidation: ValidationState = .idle

    public var onCompletion: (() -> Void)?
    public var onRequestRestart: (() -> Void)?

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
        case .geminiKey:
            return geminiValidation.isSuccess
        case .completion:
            return true
        }
    }

    private let permissionRepository: PermissionRepository
    private let apiKeyRepository: ApiKeyRepository
    private let externalLinkRepository: ExternalLinkRepository
    private let validateApiKeyUseCase: ValidateApiKeyUseCaseProtocol
    private var permissionTimer: Timer?
    private var groqValidationTask: Task<Void, Never>?
    private var geminiValidationTask: Task<Void, Never>?

    private static let hasCompletedWelcomeKey = "hasCompletedWelcome"

    private var hasCompletedWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasCompletedWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasCompletedWelcomeKey) }
    }

    public init(
        permissionRepository: PermissionRepository,
        apiKeyRepository: ApiKeyRepository,
        externalLinkRepository: ExternalLinkRepository,
        validateApiKeyUseCase: ValidateApiKeyUseCaseProtocol
    ) {
        self.permissionRepository = permissionRepository
        self.apiKeyRepository = apiKeyRepository
        self.externalLinkRepository = externalLinkRepository
        self.validateApiKeyUseCase = validateApiKeyUseCase
        refreshPermissions()
        refresh()
    }

    public func refresh() {
        groqKey = apiKeyRepository.loadKey(for: .groq) ?? ""
        geminiKey = apiKeyRepository.loadKey(for: .gemini) ?? ""
        groqValidation = groqKey.isEmpty ? .idle : .success
        geminiValidation = geminiKey.isEmpty ? .idle : .success
        refreshPermissions()
        syncStep()
        revalidateStoredKeys()
    }

    private func revalidateStoredKeys() {
        let groqTrimmed = groqKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !groqTrimmed.isEmpty {
            Task {
                do {
                    try await validateGroqKeyValue(groqTrimmed)
                } catch {
                    if !Task.isCancelled && currentGroqKeyMatches(groqTrimmed) {
                        groqValidation = .failure(errorMessage(for: error, provider: "Groq"))
                    }
                }
            }
        }

        let geminiTrimmed = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !geminiTrimmed.isEmpty {
            Task {
                do {
                    try await validateGeminiKeyValue(geminiTrimmed)
                } catch {
                    if !Task.isCancelled && currentGeminiKeyMatches(geminiTrimmed) {
                        geminiValidation = .failure(errorMessage(for: error, provider: "Gemini"))
                    }
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

    public func validateGroqKey() {
        let trimmed = groqKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            groqValidation = .failure("Enter your Groq API key to continue.")
            return
        }

        groqValidationTask?.cancel()
        groqValidation = .validating

        groqValidationTask = Task {
            do {
                try await validateGroqKeyValue(trimmed)
                if Task.isCancelled || !currentGroqKeyMatches(trimmed) { return }
                groqValidation = .success
                try? apiKeyRepository.saveKey(trimmed, for: .groq)
            } catch {
                if Task.isCancelled || !currentGroqKeyMatches(trimmed) { return }
                groqValidation = .failure(errorMessage(for: error, provider: "Groq"))
            }
        }
    }

    public func validateGeminiKey() {
        let trimmed = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            geminiValidation = .failure("Enter your Gemini API key to continue.")
            return
        }

        geminiValidationTask?.cancel()
        geminiValidation = .validating

        geminiValidationTask = Task {
            do {
                try await validateGeminiKeyValue(trimmed)
                if Task.isCancelled || !currentGeminiKeyMatches(trimmed) { return }
                geminiValidation = .success
                try? apiKeyRepository.saveKey(trimmed, for: .gemini)
            } catch {
                if Task.isCancelled || !currentGeminiKeyMatches(trimmed) { return }
                geminiValidation = .failure(errorMessage(for: error, provider: "Gemini"))
            }
        }
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

        if geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            step = .geminiKey
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

    private func validateGroqKeyValue(_ key: String) async throws {
        try await validateApiKeyUseCase.execute(key: key, for: .groq)
    }

    private func validateGeminiKeyValue(_ key: String) async throws {
        try await validateApiKeyUseCase.execute(key: key, for: .gemini)
    }

    private func currentGroqKeyMatches(_ key: String) -> Bool {
        groqKey.trimmingCharacters(in: .whitespacesAndNewlines) == key
    }

    private func currentGeminiKeyMatches(_ key: String) -> Bool {
        geminiKey.trimmingCharacters(in: .whitespacesAndNewlines) == key
    }
}
