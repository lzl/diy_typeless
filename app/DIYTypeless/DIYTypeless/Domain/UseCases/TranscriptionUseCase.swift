import Foundation

struct TranscriptionResult: Sendable {
    let rawText: String
    let polishedText: String
    let outputResult: OutputResult
}

protocol TranscriptionUseCaseProtocol: Sendable {
    func execute(groqKey: String, geminiKey: String, context: String?) async throws -> TranscriptionResult
}
