import Foundation

enum OutputMethod: Sendable {
    case pasted
    case copied
}

struct TranscriptionResult: Sendable {
    let rawText: String
    let polishedText: String
    let outputMethod: OutputMethod
}

protocol TranscriptionUseCaseProtocol: Sendable {
    func execute(groqKey: String, geminiKey: String, context: String?) async throws -> TranscriptionResult
}
