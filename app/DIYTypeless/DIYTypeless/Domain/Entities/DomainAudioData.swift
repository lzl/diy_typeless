import Foundation

/// Domain-owned audio payload used by transcription use cases.
struct DomainAudioData: Sendable {
    let bytes: Data
    let durationSeconds: Float
}
