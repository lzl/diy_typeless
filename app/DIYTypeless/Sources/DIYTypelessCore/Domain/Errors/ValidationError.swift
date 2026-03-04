import Foundation

struct ValidationError: LocalizedError, Equatable {
    let message: String

    var errorDescription: String? {
        message
    }
}
