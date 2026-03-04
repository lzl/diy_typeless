import Foundation

/// Domain-level categories for technical failures from outer layers.
enum TechnicalErrorCategory: Sendable {
    case api
    case network
    case unknown
}

/// Maps technical failures to user-facing errors.
/// Shared across all UseCase implementations to avoid code duplication.
enum CoreErrorMapper {
    static func toUserFacingError(category: TechnicalErrorCategory, message: String) -> UserFacingError {
        switch category {
        case .api:
            let lowercased = message.lowercased()
            if lowercased.contains("401") {
                return .invalidAPIKey
            }
            if lowercased.contains("400") || lowercased.contains("403") {
                return .regionBlocked
            }
            if lowercased.contains("429") {
                return .rateLimited
            }
            if lowercased.contains("500") ||
                lowercased.contains("502") ||
                lowercased.contains("503") ||
                lowercased.contains("504") {
                return .serviceUnavailable
            }
            return .unknown(message)
        case .network:
            return .networkError
        case .unknown:
            return .unknown(message)
        }
    }
}
