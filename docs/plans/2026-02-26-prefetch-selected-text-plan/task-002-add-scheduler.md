# Task 002: Add PrefetchScheduler Protocol and Implementations

## Description

Create `PrefetchScheduler` protocol to abstract time-based scheduling for testability.

## BDD Scenario

N/A - Infrastructure task

## Implementation Requirements

### 1. Create Protocol

```swift
// Domain/Protocols/PrefetchScheduler.swift
protocol PrefetchScheduler: Sendable {
    func schedule(
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never>

    func cancel(_ task: Task<Void, Never>)
}
```

### 2. Create Real Implementation

```swift
// Infrastructure/Scheduling/RealPrefetchScheduler.swift
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
```

### 3. Create Mock Implementation for Tests

```swift
// Tests/Mocks/MockPrefetchScheduler.swift
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
```

## Acceptance Criteria

- [ ] `PrefetchScheduler` protocol created in Domain layer
- [ ] `RealPrefetchScheduler` implementation created
- [ ] `MockPrefetchScheduler` created with `executeScheduled()` helper
- [ ] All types are `Sendable` compliant

## Location

- Protocol: `app/DIYTypeless/DIYTypeless/Domain/Protocols/PrefetchScheduler.swift`
- Real: `app/DIYTypeless/DIYTypeless/Infrastructure/Scheduling/RealPrefetchScheduler.swift`
- Mock: `app/DIYTypeless/DIYTypelessTests/Mocks/MockPrefetchScheduler.swift`

## depends-on

- Task 001

## Estimated Effort

20 minutes
