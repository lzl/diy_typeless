import Foundation

/// Result of the complete transcription pipeline
struct TranscriptionResult: Sendable {
    let rawText: String
    let polishedText: String
    let outputResult: OutputResult
}
