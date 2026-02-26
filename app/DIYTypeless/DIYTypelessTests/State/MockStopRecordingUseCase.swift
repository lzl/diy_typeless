import Foundation
@testable import DIYTypeless

/// Mock implementation of StopRecordingUseCaseProtocol for testing.
/// Allows configurable delay, return value, and error throwing to test parallel execution timing.
@MainActor
final class MockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    /// Delay in seconds before returning (default: 0)
    var configuredDelay: TimeInterval = 0

    /// The AudioData to return (default: empty audio data)
    var returnValue: AudioData?

    /// Error to throw (if any)
    var errorToThrow: RecordingError?

    /// Track execution count
    private(set) var executeCount = 0

    /// Track last execution time
    private(set) var lastExecutionTime: Date?

    func execute() async throws -> AudioData {
        executeCount += 1
        lastExecutionTime = Date()

        if configuredDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(configuredDelay * 1_000_000_000))
        }

        if let error = errorToThrow {
            throw error
        }

        guard let audioData = returnValue else {
            throw RecordingError.invalidAudioData
        }

        return audioData
    }

    /// Reset the mock state
    func reset() {
        executeCount = 0
        lastExecutionTime = nil
        errorToThrow = nil
    }
}
