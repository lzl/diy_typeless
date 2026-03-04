import Foundation

public enum ValidationState: Equatable, Sendable {
    case idle
    case validating
    case success
    case failure(String)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var message: String? {
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
