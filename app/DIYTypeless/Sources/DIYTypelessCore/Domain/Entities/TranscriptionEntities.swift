import Foundation

/// Result of the complete transcription pipeline
public struct TranscriptionResult: Sendable {
    public let rawText: String
    public let polishedText: String
    public let outputResult: OutputResult

    public init(rawText: String, polishedText: String, outputResult: OutputResult) {
        self.rawText = rawText
        self.polishedText = polishedText
        self.outputResult = outputResult
    }
}
