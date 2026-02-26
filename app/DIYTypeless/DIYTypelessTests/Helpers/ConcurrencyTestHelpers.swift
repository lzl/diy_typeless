import Foundation
@testable import DIYTypeless

/// Helper function to measure elapsed time from a start point
/// - Parameter start: The start time
/// - Returns: Elapsed time in seconds
func timeElapsed(since start: Date) -> TimeInterval {
    Date().timeIntervalSince(start)
}

/// Helper function to measure execution time of an async block
/// - Parameter block: The async block to execute
/// - Returns: Tuple of (result, elapsed time in seconds)
func measureAsync<T>(
    _ block: () async throws -> T
) async rethrows -> (result: T, elapsed: TimeInterval) {
    let start = Date()
    let result = try await block()
    let elapsed = timeElapsed(since: start)
    return (result, elapsed)
}

/// Helper function to measure execution time of an async void block
/// - Parameter block: The async void block to execute
/// - Returns: Elapsed time in seconds
func measureAsyncVoid(
    _ block: () async -> Void
) async -> TimeInterval {
    let start = Date()
    await block()
    return timeElapsed(since: start)
}

/// Assert that two operations executed in parallel
/// - Parameters:
///   - totalTime: The total elapsed time for both operations
///   - delay1: The configured delay for operation 1
///   - delay2: The configured delay for operation 2
///   - tolerance: Tolerance in seconds (default: 0.05 for 50ms)
/// - Returns: True if operations executed in parallel (total ≈ max of delays)
func assertParallelExecution(
    totalTime: TimeInterval,
    delay1: TimeInterval,
    delay2: TimeInterval,
    tolerance: TimeInterval = 0.05
) -> Bool {
    let expectedMax = max(delay1, delay2)
    let expectedSerial = delay1 + delay2

    // Parallel: total should be close to max of individual delays
    let isParallel = abs(totalTime - expectedMax) <= tolerance

    // Serial: total should be close to sum of delays
    let isSerial = abs(totalTime - expectedSerial) <= tolerance

    return isParallel && !isSerial
}

/// Helper to create empty AudioData for testing
/// This uses the FFI generated AudioData type
func createEmptyAudioData() -> AudioData {
    // Create minimal valid audio data
    AudioData(bytes: Data(), durationSeconds: 0.0)
}

/// Helper to create AudioData with sample content for testing
func createAudioData(bytes: Data = Data([0x01, 0x02, 0x03]), duration: Float = 1.0) -> AudioData {
    AudioData(bytes: bytes, durationSeconds: duration)
}
