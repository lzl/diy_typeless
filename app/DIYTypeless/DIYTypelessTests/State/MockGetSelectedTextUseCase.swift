import Foundation
@testable import DIYTypeless

/// Mock implementation of GetSelectedTextUseCaseProtocol for testing.
/// Allows configurable delay and return value to test parallel execution timing.
@MainActor
final class MockGetSelectedTextUseCase: GetSelectedTextUseCaseProtocol {
    /// Delay in seconds before returning (default: 0)
    var configuredDelay: TimeInterval = 0

    /// The SelectedTextContext to return (default: empty context)
    var returnValue: SelectedTextContext = SelectedTextContext(
        text: nil,
        isEditable: false,
        isSecure: false,
        applicationName: "TestApp"
    )

    /// Track execution count
    private(set) var executeCount = 0

    /// Track last execution time
    private(set) var lastExecutionTime: Date?

    func execute() async -> SelectedTextContext {
        executeCount += 1
        lastExecutionTime = Date()

        if configuredDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(configuredDelay * 1_000_000_000))
        }

        return returnValue
    }

    /// Reset the mock state
    func reset() {
        executeCount = 0
        lastExecutionTime = nil
    }
}
