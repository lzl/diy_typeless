import Foundation

public enum ApiProvider: String, Sendable, CaseIterable {
    case groq
    case gemini
    case openai

    public static var llmProviders: [ApiProvider] {
        [.gemini, .openai]
    }

    public var isLLMProvider: Bool {
        self != .groq
    }

    public var displayName: String {
        switch self {
        case .groq:
            return "Groq"
        case .gemini:
            return "Google (Gemini)"
        case .openai:
            return "OpenAI"
        }
    }

    public var apiKeyPlaceholder: String {
        "Enter your \(displayName) API key"
    }

    public var consoleURL: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        case .gemini:
            return "https://aistudio.google.com/app/api-keys"
        case .openai:
            return "https://platform.openai.com/api-keys"
        }
    }
}
