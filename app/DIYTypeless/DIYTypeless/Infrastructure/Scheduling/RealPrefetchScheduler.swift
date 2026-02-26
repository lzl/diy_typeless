final class RealPrefetchScheduler: PrefetchScheduler {
    func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel(_ task: Task<Void, Never>) {
        task.cancel()
    }
}
