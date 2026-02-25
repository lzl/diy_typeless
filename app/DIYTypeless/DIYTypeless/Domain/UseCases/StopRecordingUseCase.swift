import Foundation

// WavData is defined in DIYTypelessCore.swift (FFI generated)
// Extension to make it conform to Sendable for our use
extension WavData: @unchecked Sendable {}

/// Protocol for stopping recording and retrieving audio data
protocol StopRecordingUseCaseProtocol: Sendable {
    /// Stops the current recording and returns the WAV audio data
    /// - Returns: WAV audio data
    /// - Throws: RecordingError if no recording is in progress or stop fails
    func execute() async throws -> WavData
}

enum RecordingError: Error {
    case notRecording
    case stopFailed(String)
    case invalidAudioData
}
