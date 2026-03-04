import Foundation

/// Domain-owned audio payload used by transcription use cases.
public struct DomainAudioData: Sendable {
    public let bytes: Data
    public let durationSeconds: Float

    public init(bytes: Data, durationSeconds: Float) {
        self.bytes = bytes
        self.durationSeconds = durationSeconds
    }
}
