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
}
