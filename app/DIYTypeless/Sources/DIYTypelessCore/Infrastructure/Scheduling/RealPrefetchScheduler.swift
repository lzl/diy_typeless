public final class RealPrefetchScheduler: PrefetchScheduler {
    public init() {}

    public func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel(_ task: Task<Void, Never>) {
        task.cancel()
    }
}
