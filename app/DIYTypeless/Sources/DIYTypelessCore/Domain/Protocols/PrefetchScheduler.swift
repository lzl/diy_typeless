protocol PrefetchScheduler: Sendable {
    func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never>

    func cancel(_ task: Task<Void, Never>)
}
