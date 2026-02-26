import Foundation
@testable import DIYTypeless

final class MockPrefetchScheduler: PrefetchScheduler {
    private(set) var scheduledOperations: [(delay: Duration, operation: () async -> Void)] = []
    private(set) var cancelledTasks: [Task<Void, Never>] = []

    func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        scheduledOperations.append((delay, operation))
        return Task {
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    func cancel(_ task: Task<Void, Never>) {
        cancelledTasks.append(task)
        task.cancel()
    }

    func executeScheduled() async {
        for (_, operation) in scheduledOperations {
            await operation()
        }
    }

    func reset() {
        scheduledOperations.removeAll()
        cancelledTasks.removeAll()
    }
}
