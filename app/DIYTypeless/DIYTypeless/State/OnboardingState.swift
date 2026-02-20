import Combine
import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case asrProvider
    case groqKey
    case geminiKey
    case completion

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

enum ValidationState: Equatable {
    case idle
    case validating
    case success
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .idle, .success:
            return nil
        case .validating:
            return "Validating..."
        case .failure(let message):
            return message
        }
    }
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var permissions = PermissionStatus(accessibility: false, microphone: false)
    @Published var asrProvider: AsrProvider = AsrSettings.shared.currentProvider {
        didSet {
            AsrSettings.shared.currentProvider = asrProvider
        }
    }
    @Published var groqKey: String = "" {
        didSet {
            if groqKey != oldValue {
                groqValidation = .idle
            }
        }
    }
    @Published var geminiKey: String = "" {
        didSet {
            if geminiKey != oldValue {
                geminiValidation = .idle
            }
        }
    }
    @Published var groqValidation: ValidationState = .idle
    @Published var geminiValidation: ValidationState = .idle

    var onCompletion: (() -> Void)?
    var onRequestRestart: (() -> Void)?

    var canProceed: Bool {
        switch step {
        case .welcome:
            return true
        case .microphone:
            return permissions.microphone
        case .accessibility:
            return permissions.accessibility
        case .asrProvider:
            // Just a selection step, always allow proceeding
            return true
        case .groqKey:
            // Show different content based on ASR provider
            if asrProvider == .local {
                return LocalAsrManager.shared.isModelLoaded
            } else {
                return groqValidation.isSuccess
            }
        case .geminiKey:
            return geminiValidation.isSuccess
        case .completion:
            return true
        }
    }

    private let permissionManager: PermissionManager
    private let keyStore: ApiKeyStore
    private var permissionTimer: Timer?
    private var groqValidationTask: Task<Void, Never>?
    private var geminiValidationTask: Task<Void, Never>?

    private static let hasCompletedWelcomeKey = "hasCompletedWelcome"

    private var hasCompletedWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasCompletedWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasCompletedWelcomeKey) }
    }

    init(permissionManager: PermissionManager, keyStore: ApiKeyStore) {
        self.permissionManager = permissionManager
        self.keyStore = keyStore
        refreshPermissions()
        refresh()
    }

    func refresh() {
        groqKey = keyStore.loadGroqKey() ?? ""
        geminiKey = keyStore.loadGeminiKey() ?? ""
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
                    if !Task.isCancelled {
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
                    if !Task.isCancelled {
                        geminiValidation = .failure(errorMessage(for: error, provider: "Gemini"))
                    }
                }
            }
        }
    }

    func startPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPermissions()
            }
        }
    }

    func stopPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    func goNext() {
        if step == .welcome {
            hasCompletedWelcome = true
        }
        if let next = step.next {
            // After groqKey step with Local ASR, we already showed download view
            // and now should go to geminiKey (which is next in the enum)
            step = next
        }
    }

    func goBack() {
        if let previous = step.previous {
            step = previous
        }
    }

    func complete() {
        onCompletion?()
    }

    func showCompletion() {
        step = .completion
    }

    func requestRestart() {
        onRequestRestart?()
    }

    func requestMicrophonePermission() {
        permissionManager.requestMicrophone { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPermissions()
            }
        }
    }

    func requestAccessibilityPermission() {
        _ = permissionManager.requestAccessibility()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    func openMicrophoneSettings() {
        permissionManager.openMicrophoneSettings()
    }

    func validateGroqKey() {
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
                if Task.isCancelled { return }
                groqValidation = .success
                keyStore.saveGroqKey(trimmed)
            } catch {
                if Task.isCancelled { return }
                groqValidation = .failure(errorMessage(for: error, provider: "Groq"))
            }
        }
    }

    func validateGeminiKey() {
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
                if Task.isCancelled { return }
                geminiValidation = .success
                keyStore.saveGeminiKey(trimmed)
            } catch {
                if Task.isCancelled { return }
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

        // Check if ASR provider is selected and configured
        let settings = AsrSettings.shared
        if settings.currentProvider == .local {
            // Local ASR: check if model is loaded (at groqKey step which shows download view)
            if !LocalAsrManager.shared.isModelLoaded {
                step = .groqKey
                return
            }
        } else {
            // Groq ASR: check API key
            if groqKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                step = .groqKey
                return
            }
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
        permissions = permissionManager.currentStatus()
    }

    private func errorMessage(for error: Error, provider: String) -> String {
        if let validationError = error as? ValidationError {
            return validationError.message
        }
        return "\(provider) validation failed: \(error.localizedDescription)"
    }

    private func validateGroqKeyValue(_ key: String) async throws {
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else {
            throw ValidationError(message: "Groq validation failed: invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError(message: "Groq validation failed: no response.")
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw ValidationError(message: "Groq API key is invalid or expired.")
        default:
            throw ValidationError(message: "Groq API error: HTTP \(http.statusCode).")
        }
    }

    private func validateGeminiKeyValue(_ key: String) async throws {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            throw ValidationError(message: "Gemini validation failed: invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError(message: "Gemini validation failed: no response.")
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw ValidationError(message: "Gemini API key is invalid or expired.")
        default:
            throw ValidationError(message: "Gemini API error: HTTP \(http.statusCode).")
        }
    }
}

private struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
