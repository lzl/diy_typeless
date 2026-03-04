import Foundation

/// Protocol for stopping recording and retrieving audio data
protocol StopRecordingUseCaseProtocol: Sendable {
    /// Stops the current recording and returns the audio data (FLAC format)
    /// - Returns: Audio data
    /// - Throws: RecordingError if no recording is in progress or stop fails
    func execute() async throws -> DomainAudioData
}

enum RecordingError: Error {
    case notRecording
    case stopFailed(String)
    case invalidAudioData
}
