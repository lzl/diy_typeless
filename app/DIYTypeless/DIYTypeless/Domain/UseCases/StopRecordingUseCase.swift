import Foundation

// AudioData is defined in DIYTypelessCore.swift (FFI generated)
// Extension to make it conform to Sendable for our use
extension AudioData: @unchecked Sendable {}

/// Protocol for stopping recording and retrieving audio data
protocol StopRecordingUseCaseProtocol: Sendable {
    /// Stops the current recording and returns the audio data (FLAC format)
    /// - Returns: Audio data
    /// - Throws: RecordingError if no recording is in progress or stop fails
    func execute() async throws -> AudioData
}

enum RecordingError: Error {
    case notRecording
    case stopFailed(String)
    case invalidAudioData
}
