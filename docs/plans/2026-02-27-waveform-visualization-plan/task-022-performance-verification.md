# Task 022: Performance Verification

## BDD Scenario

```gherkin
Scenario: Waveform renders without blocking main thread
  Given the waveform is actively animating
  When audio processing occurs simultaneously
  Then the main thread should not be blocked
  And UI interactions should remain responsive
  And the waveform animation should continue uninterrupted
  And TimelineView should handle display link callbacks efficiently
```

```gherkin
Scenario: Memory usage remains constant during recording
  Given the waveform has been animating for 5 minutes
  When memory usage is measured
  Then there should be no memory leaks
  And memory usage should not grow linearly with time
  And the renderer's smoothedLevels array size should remain constant
  And peak memory should remain under 10MB for waveform component
```

```gherkin
Scenario: Waveform animates smoothly at 60fps
  Given the waveform is active
  When audio levels are changing continuously
  Then the animation should maintain 60 frames per second
  And the TimelineView should drive the animation updates
  And no individual frame should take longer than 16.67ms to render
  And the renderer state should persist across frames
```

## Description

Verify the waveform visualization meets all performance criteria defined in the design document.

## Acceptance Criteria

| Metric | Target | Verification Method |
|--------|--------|---------------------|
| Animation Frame Rate | >= 60fps | CADisplayLink callback timing |
| CPU Usage | < 5% on M1 Mac | Activity Monitor during recording |
| Memory Growth | Zero growth over 10min | Xcode Memory Graph |
| Main Thread Blocking | None | Instruments Time Profiler |

## Performance Tests to Run

1. **Frame Rate Test**: Use `XCTOSSignPostMetric` or custom CADisplayLink metric
2. **Memory Test**: Record 10-minute session, verify no memory growth
3. **CPU Test**: Measure CPU usage during active recording
4. **Stress Test**: Rapid style switching 100 times, verify no leaks

## Files to Create

- `DIYTypelessTests/Performance/WaveformPerformanceTests.swift` (create)

## Implementation Sketch

```swift
final class WaveformPerformanceTests: XCTestCase {
    func testFrameRateDuringRecording() throws {
        measure(metrics: [XCTOSSignPostMetric.animationDuration]) {
            // 30-second recording simulation
        }
    }

    func testMemoryStability() throws {
        // Run for extended period, verify constant memory
    }
}
```

## Verification Steps

1. Build in Release mode for accurate measurements
2. Profile with Instruments:
   - Time Profiler (check main thread usage)
   - Allocations (check for memory leaks)
   - Core Animation (check for dropped frames)
3. Manual testing: 60-second recording with Activity Monitor

## Depends On

- Task 021: Capsule Integration - Implementation

## Verification

```bash
# Build for Release
xcodebuild -project app/DIYTypeless/DIYTypeless.xcodeproj \
  -scheme DIYTypeless \
  -configuration Release \
  -destination 'platform=macOS' \
  build

# Run performance tests
xcodebuild test -project app/DIYTypeless/DIYTypeless.xcodeproj \
  -scheme DIYTypeless \
  -only-testing:WaveformPerformanceTests
```

Expected: All performance metrics meet or exceed targets.
