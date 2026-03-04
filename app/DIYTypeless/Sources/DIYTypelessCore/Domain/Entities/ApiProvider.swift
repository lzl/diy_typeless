import Foundation

enum ApiProvider: String, Sendable, CaseIterable {
    case groq
    case gemini

    var displayName: String {
        switch self {
        case .groq:
            return "Groq"
        case .gemini:
            return "Gemini"
        }
    }

    var consoleURL: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        case .gemini:
            return "https://aistudio.google.com/app/api-keys"
        }
    }
}
