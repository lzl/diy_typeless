import Foundation

/// User-facing error types for display in the UI.
/// These errors are mapped from technical CoreError and provide
/// user-friendly messages suitable for display in the capsule UI.
enum UserFacingError: Error, Equatable {
    case invalidAPIKey
    case regionBlocked
    case rateLimited
    case serviceUnavailable
    case networkError
    case unknown(String)
}

extension UserFacingError {
    /// The user-friendly error message for display.
    /// Messages are kept concise to fit in the capsule UI (~160px width).
    var message: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .regionBlocked:
            return "Service unavailable in your region"
        case .rateLimited:
            return "Rate limited, try again soon"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .networkError:
            return "Network error, check connection"
        case .unknown(let msg):
            // For unknown errors, try to keep it concise
            if msg.count > 30 {
                return String(msg.prefix(27)) + "..."
            }
            return msg
        }
    }

    /// The severity level of the error, used to determine display color.
    var severity: ErrorSeverity {
        switch self {
        case .invalidAPIKey, .rateLimited:
            return .warning
        case .regionBlocked, .serviceUnavailable, .networkError, .unknown:
            return .critical
        }
    }
}

/// Error severity levels for UI color selection.
enum ErrorSeverity: Equatable {
    case warning     // User-fixable issues
    case critical    // External/system issues
}
