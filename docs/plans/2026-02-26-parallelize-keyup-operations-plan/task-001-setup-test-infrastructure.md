# Task 001: Setup Test Infrastructure

## BDD Scenario

This task sets up the foundation for all subsequent BDD scenarios. No specific scenario - this is infrastructure preparation.

## Goal

Create mock implementations of `GetSelectedTextUseCase` and `StopRecordingUseCase` that allow controlled testing of parallel execution timing, plus supporting infrastructure for `RecordingState` tests.

## What to Do

1. **Create MockGetSelectedTextUseCase**:
   - Implement a mock that conforms to `GetSelectedTextUseCaseProtocol`
   - Add a configurable delay property (in milliseconds)
   - Add a configurable return value for selected text context
   - Track execution count and last execution time

2. **Create MockStopRecordingUseCase**:
   - Implement a mock that conforms to `StopRecordingUseCaseProtocol`
   - Add a configurable delay property (in milliseconds)
   - Add a configurable return value for audio data
   - Add ability to throw an error on demand
   - Track execution count and last execution time

3. **Create Test Helpers**:
   - Add a helper to measure elapsed time between two points
   - Add a helper to assert that two operations executed in parallel (total time ≈ max of individual delays, not sum)

4. **Create RecordingStateTestFactory** (NEW):
   - Factory method to create `RecordingState` with minimal configuration
   - Provide default mocks for all dependencies:
     - `PermissionRepository` mock
     - `ApiKeyRepository` mock
     - `KeyMonitoringRepository` mock
     - `TextOutputRepository` mock
     - `AppContextRepository` mock
     - `RecordingControlUseCaseProtocol` mock
     - `TranscribeAudioUseCaseProtocol` mock
     - `PolishTextUseCaseProtocol` mock
     - `ProcessVoiceCommandUseCaseProtocol` mock
   - Allow overriding specific mocks for targeted tests

## Files to Create/Modify

- `app/DIYTypeless/DIYTypelessTests/State/MockGetSelectedTextUseCase.swift` (new)
- `app/DIYTypeless/DIYTypelessTests/State/MockStopRecordingUseCase.swift` (new)
- `app/DIYTypeless/DIYTypelessTests/Helpers/ConcurrencyTestHelpers.swift` (new)
- `app/DIYTypeless/DIYTypelessTests/Factories/RecordingStateTestFactory.swift` (new)

## Verification

- [ ] Mock classes compile without errors
- [ ] Mock classes can be instantiated with custom delays
- [ ] Mock classes track execution correctly

## Acceptance Criteria

1. `MockGetSelectedTextUseCase` can be configured with a delay and returns the configured value after that delay
2. `MockStopRecordingUseCase` can be configured with a delay and returns the configured value or throws an error
3. Test helpers can measure elapsed time with millisecond precision
4. Test helpers can assert parallel execution (total time is within tolerance of max delay)

## Dependencies

None - this is foundational infrastructure
