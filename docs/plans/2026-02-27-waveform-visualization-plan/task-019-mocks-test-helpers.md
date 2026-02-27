# Task 019: Mock Objects and Test Helpers

## BDD Scenario

```gherkin
Scenario: Preview renders waveform with mock data
  Given the developer is viewing SwiftUI preview
  When the preview canvas displays WaveformContainerView
  Then the waveform should render with simulated audio levels
  And the preview should use MockAudioLevelProvider
  And the preview should demonstrate the default style
  And the renderer should initialize correctly in preview context
```

## Description

Create mock implementations and test helpers for testing the waveform system without real audio dependencies.

## Acceptance Criteria

1. Create `MockAudioLevelMonitor` (actor) for testing with AsyncStream
2. Create `MockWaveformRenderer` for testing
3. Provide test data fixtures (silence, normal, max levels)
4. All mocks conform to appropriate protocols
5. Mocks use proper isolation (`actor` for AudioLevelMonitor, `@MainActor` for Renderer)

## Files to Create/Modify

- `DIYTypelessTests/Mocks/MockAudioLevelMonitor.swift` (create)
- `DIYTypelessTests/Mocks/MockWaveformRenderer.swift` (create)
- `DIYTypelessTests/Helpers/WaveformTestData.swift` (create)

## Implementation Sketch

```swift
// MockAudioLevelMonitor.swift
actor MockAudioLevelMonitor: AudioLevelProviding {
    private(set) var levels: [Double] = []
    private var continuation: AsyncStream<[Double]>.Continuation?

    var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    init(levels: [Double] = []) {
        self.levels = levels
    }

    func simulateLevels(_ newLevels: [Double]) {
        levels = newLevels
        continuation?.yield(newLevels)
    }

    func simulateRecording() async {
        // Simulate varying levels over time
        let patterns: [[Double]] = [
            [0.0, 0.1, 0.2, 0.1, 0.0],
            [0.2, 0.4, 0.6, 0.4, 0.2],
            [0.5, 0.7, 0.9, 0.7, 0.5],
            [0.3, 0.5, 0.7, 0.5, 0.3],
        ]
        for levels in patterns {
            simulateLevels(levels)
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

// MockWaveformRenderer.swift
@MainActor
final class MockWaveformRenderer: WaveformRendering {
    var renderCallCount = 0
    var lastRenderParameters: (size: CGSize, levels: [Double], time: Date)?

    func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
        renderCallCount += 1
        lastRenderParameters = (size, levels, time)
    }
}

// WaveformTestData.swift
enum WaveformTestData {
    static let silence: [Double] = [0.0, 0.0, 0.0]
    static let normal: [Double] = [0.25, 0.5, 0.75, 0.5, 0.25]
    static let maximum: [Double] = [1.0, 1.0, 1.0]
    static let decay: [Double] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.1]
    static let empty: [Double] = []
    static let rapidAlternation: [Double] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    static let largeArray: [Double] = Array(repeating: 0.5, count: 1000)
}
```

## Depends On

- Task 018: Presentation Layer - WaveformSettings (Implementation)

## Verification

```bash
# Build and run tests
./scripts/dev-loop-build.sh --testing
```

Expected: All mocks compile and can be used in tests.
