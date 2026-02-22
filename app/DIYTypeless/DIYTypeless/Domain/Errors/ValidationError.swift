import Foundation

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
