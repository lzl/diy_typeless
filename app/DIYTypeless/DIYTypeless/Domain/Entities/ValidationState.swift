import Foundation

enum ValidationState: Equatable, Sendable {
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
