# Task 021: Capsule Integration - Implementation

## BDD Scenario

```gherkin
Scenario: Waveform displays in capsule during recording state
  Given the app is in idle state showing the capsule
  When the user initiates recording
  Then the capsule should transition to recording state
  And the waveform visualization should appear inside the capsule
  And the waveform should be centered vertically in the capsule
  And the waveform width should adapt to capsule size
```

```gherkin
Scenario: Waveform transitions smoothly when recording stops
  Given the waveform is actively animating in the capsule
  When the user stops recording
  Then the waveform should fade out over 200ms
  And the capsule should transition to processing state
  And the renderer should not leak memory after transition
```

## Description

Integrate the waveform visualization into the existing Capsule window system. Replace the legacy HStack-based waveform with the new Canvas-based implementation.

## Acceptance Criteria

1. Modify Capsule view to use `WaveformContainerView` during recording
2. Show waveform only in `.recording` state
3. Center waveform vertically in capsule
4. Implement 200ms fade-out on stop
5. Ensure proper memory cleanup (renderer deallocation)
6. Add accessibility label for VoiceOver
7. All tests from Task 020 pass

## Files to Modify

- `DIYTypeless/Capsule/CapsuleView.swift` (modify - integrate waveform)
- `DIYTypeless/Capsule/CapsuleWindow.swift` (review - ensure compatibility)

## Implementation Sketch

### Option A: Constructor Injection (Recommended for explicit dependencies)

```swift
// CapsuleView.swift
struct CapsuleView: View {
    private let audioMonitor: AudioLevelMonitor
    private let waveformSettings: WaveformSettings

    @State private var state: CapsuleState

    init(
        state: CapsuleState,
        audioMonitor: AudioLevelMonitor,
        waveformSettings: WaveformSettings
    ) {
        self._state = State(initialValue: state)
        self.audioMonitor = audioMonitor
        self.waveformSettings = waveformSettings
    }

    var body: some View {
        HStack {
            // ... other capsule content

            waveformSection

            // ... other capsule content
        }
    }

    @ViewBuilder
    private var waveformSection: some View {
        if case .recording = state.phase {
            WaveformContainerView(
                audioMonitor: audioMonitor,
                style: waveformSettings.selectedStyle
            )
            .frame(height: 40)
            .transition(.opacity.animation(.easeOut(duration: 0.2)))
            .accessibilityLabel("Recording audio")
        }
    }
}
```

### Option B: Environment Injection (for global state)

```swift
// In App entry point or parent view:
ContentView()
    .environment(audioMonitor)
    .environment(waveformSettings)

// CapsuleView.swift
struct CapsuleView: View {
    @Environment(AudioLevelMonitor.self) private var audioMonitor
    @Environment(WaveformSettings.self) private var waveformSettings
    @State private var state: CapsuleState

    // ... rest of implementation
}
```

### CapsuleState Updates

```swift
// CapsuleState.swift
@MainActor
@Observable
final class CapsuleState {
    enum Phase {
        case idle
        case recording
        case processing
    }

    private(set) var phase: Phase = .idle
    private let audioMonitor: AudioLevelMonitor

    init(audioMonitor: AudioLevelMonitor) {
        self.audioMonitor = audioMonitor
    }

    func startRecording() async {
        phase = .recording
        try? await audioMonitor.startMonitoring()
    }

    func stopRecording() {
        phase = .processing
        Task {
            await audioMonitor.stopMonitoring()
        }
    }
}
```

## Integration Points

1. **Dependency Injection**: Pass `AudioLevelMonitor` and `WaveformSettings` via constructor or @Environment
2. **State Management**: CapsuleState controls when audio monitoring starts/stops
3. **Lifecycle**: Audio monitoring starts on `.recording`, stops when leaving that state
4. **Cleanup**: AudioLevelMonitor handles tap removal and engine stop
5. **Accessibility**: Added VoiceOver label "Recording audio"

## Depends On

- Task 020: Capsule Integration - Tests

## Verification

```bash
# Run full test suite
./scripts/dev-loop-build.sh --testing

# Verify app builds
./scripts/dev-loop-build.sh
```

Expected: All tests pass, app builds successfully (Green phase).
