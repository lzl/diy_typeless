# State Layer

This layer contains **@Observable ViewModels** that manage UI state and orchestrate Domain use cases.

## Purpose

- Bridge Domain use cases with SwiftUI views
- Manage application lifecycle and state transitions
- Handle user interactions and coordinate business logic

## Files

| State | Purpose |
|-------|---------|
| `AppState` | Root application state (onboarding, recording, etc.) |
| `OnboardingState` | Onboarding flow state and logic |
| `RecordingState` | Recording session state, key handling, transcription |

## Architecture Pattern

```
SwiftUI View
     ↓ (user action)
State (@Observable)
     ↓ (calls UseCase)
Domain UseCase (protocol)
     ↓ (implemented by)
Data UseCase (implementation)
     ↓ (calls)
Repository (protocol)
     ↓ (implemented by)
Data Repository (implementation)
```

## Key Principles

1. **@Observable only** - Use modern Swift concurrency, never ObservableObject
2. **@MainActor** - All state classes must be MainActor-isolated
3. **Dependency Injection** - Receive use cases via constructor
4. **No business logic** - Delegate to use cases, don't implement here
5. **Testable** - Mock use cases for unit testing

## Example Structure

```swift
@MainActor
@Observable
final class RecordingState {
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    // ... state properties

    init(
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        getSelectedTextUseCase: GetSelectedTextUseCaseProtocol
    ) {
        self.stopRecordingUseCase = stopRecordingUseCase
        self.getSelectedTextUseCase = getSelectedTextUseCase
    }

    func handleKeyUp() async {
        // Orchestrate use cases, update state
    }
}
```

## Usage

When AI needs to understand UI behavior:
1. Look at State files to understand state machine
2. Check how use cases are combined
3. Look at SwiftUI Views for presentation only

## Testing

State classes are tested with mocked use cases. See `DIYTypelessTests/State/RecordingStateTests.swift` for examples.