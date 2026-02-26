# RecordingStateTests Flaky Tests Investigation

**Status**: Pre-existing issue (not related to PR #42)
**Created**: 2026-02-26
**Priority**: Medium
**Agent**: Fix flaky RecordingStateTests

---

## Problem Summary

4 tests in `RecordingStateTests` are failing intermittently:

| Test Name | Status |
|-----------|--------|
| `testParallelExecution_ReducedDelay` | ❌ Flaky |
| `testVoiceCommandMode_WithSelectedText` | ❌ Flaky |
| `testParallelExecution_BothExecuted` | ❌ Flaky |
| `testMultipleGenerations_OnlyLatestProcesses` | ❌ Flaky |

The other 8 tests pass consistently.

---

## Root Cause Analysis

Based on code review, these tests share common patterns that cause flakiness:

### 1. Timing-Dependent Tests

All failing tests use `Task.sleep()` with fixed nanosecond values:
- `testParallelExecution_ReducedDelay`: 50ms sleep
- `testVoiceCommandMode_WithSelectedText`: 50ms sleep
- `testParallelExecution_BothExecuted`: 50ms sleep
- `testMultipleGenerations_OnlyLatestProcesses`: 100ms, 50ms sleeps

**Problem**: Fixed sleep durations don't account for:
- System load variability
- Test execution environment (CI vs local)
- Swift concurrency scheduler non-determinism

### 2. Async State Dependencies

```swift
// Example pattern that causes flakiness:
recordingState.activate()
await recordingState.handleKeyDown()
try await Task.sleep(nanoseconds: 50_000_000)  // Fixed 50ms
await recordingState.handleKeyUp()
// ^ Expected state might not be reached yet
```

The 50ms sleep assumes the async operation completes within that time, but there's no guarantee.

### 3. Missing Async Continuations

Tests call async methods but don't wait for state transitions to complete:
- `await recordingState.handleKeyUp()` returns, but internal async tasks may still be running
- No way to verify all concurrent tasks have finished

### 4. No Timeout Handling

Tests wait indefinitely or use fixed durations without retry/timeout logic.

---

## Investigation Commands

### Run Specific Tests

```bash
# Run only RecordingStateTests
xcodebuild test -scheme DIYTypeless \
  -project app/DIYTypeless/DIYTypeless.xcodeproj \
  -destination 'platform=macOS' \
  -derivedDataPath .context/DerivedData \
  -only-testing:DIYTypelessTests/RecordingStateTests 2>&1 | \
  grep -E "(Test case.*passed|Test case.*failed)"
```

### Run Multiple Times to Confirm Flakiness

```bash
# Run 5 times to observe flakiness
for i in {1..5}; do
  echo "=== Run $i ==="
  xcodebuild test -scheme DIYTypeless \
    -project app/DIYTypeless/DIYTypeless.xcodeproj \
    -destination 'platform=macOS' \
    -derivedDataPath .context/DerivedData \
    -only-testing:DIYTypelessTests/RecordingStateTests 2>&1 | \
    grep -E "testParallelExecution_ReducedDelay|testVoiceCommandMode_WithSelectedText|testParallelExecution_BothExecuted|testMultipleGenerations_OnlyLatestProcesses" | \
    grep "failed"
done
```

---

## Recommended Fixes

### Option 1: Use AsyncStream for Deterministic Waiting (Preferred)

Instead of `Task.sleep()`, use a custom waiter that polls for expected state:

```swift
// Helper function to wait for state
func waitForState<T>(
  timeout: UInt64 = 500_000_000,  // 500ms default
  pollInterval: UInt64 = 10_000_000,  // 10ms poll
  predicate: @escaping () -> T?
) async throws -> T? {
  let deadline = DispatchTime.now().uptimeNanoseconds + timeout
  while DispatchTime.now().uptimeNanoseconds < deadline {
    if let result = predicate() {
      return result
    }
    try await Task.sleep(nanoseconds: pollInterval)
  }
  return nil
}
```

### Option 2: Increase Sleep Durations (Quick Fix)

Change all 50ms sleeps to 200ms+ to account for system variability:

```swift
// Before
try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

// After
try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
```

**Downside**: Slower test execution, may still be flaky under heavy load.

### Option 3: Use Clock API (Modern Swift)

```swift
import Foundation

let clock = ContinuousClock()
try await clock.sleep(for: .milliseconds(100))
```

### Option 4: Mock Time (Most Robust)

Use a virtual time scheduler for tests. This requires significant refactoring but provides deterministic timing.

---

## Test File Location

```
app/DIYTypeless/DIYTypelessTests/State/RecordingStateTests.swift
```

---

## Acceptance Criteria

- [ ] All 12 tests in RecordingStateTests pass consistently (100% pass rate over 10 runs)
- [ ] No test takes longer than 2 seconds to complete
- [ ] Tests pass on CI (GitHub Actions)

---

## Related Files

| File | Purpose |
|------|---------|
| `State/RecordingState.swift` | Production code being tested |
| `DIYTypelessTests/State/MockGetSelectedTextUseCase.swift` | Mock for dependency |
| `DIYTypelessTests/State/MockStopRecordingUseCase.swift` | Mock for dependency |
| `DIYTypelessTests/State/MockProcessVoiceCommandUseCase.swift` | Mock for dependency |
| `DIYTypelessTests/Factories/RecordingStateTestFactory.swift` | Test factory |
| `DIYTypelessTests/Helpers/ConcurrencyTestHelpers.swift` | Existing concurrency helpers |

---

## Notes

- Do NOT delete these tests - they validate important concurrency behavior
- The flakiness indicates real timing bugs that could affect production
- After fixing, run tests multiple times to confirm stability