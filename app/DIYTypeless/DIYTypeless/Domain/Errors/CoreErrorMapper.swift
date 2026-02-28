import Foundation

/// Maps CoreError to UserFacingError based on HTTP status codes.
/// Shared across all UseCase implementations to avoid code duplication.
enum CoreErrorMapper {
    static func toUserFacingError(_ coreError: CoreError) -> UserFacingError {
        switch coreError {
        case .Api(let message):
            let lowercased = message.lowercased()
            if lowercased.contains("401") {
                return .invalidAPIKey
            } else if lowercased.contains("400") || lowercased.contains("403") {
                return .regionBlocked
            } else if lowercased.contains("429") {
                return .rateLimited
            } else if (lowercased.contains("500") ||
                      lowercased.contains("502") ||
                      lowercased.contains("503") ||
                      lowercased.contains("504")) {
                return .serviceUnavailable
            }
            return .unknown(message)

        case .Http:
            return .networkError

        default:
            return .unknown(coreError.localizedDescription)
        }
    }
}
