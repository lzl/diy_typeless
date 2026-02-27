# BDD Specifications: Waveform Visualization System

## Overview

This document contains Behavior-Driven Development (BDD) specifications for the Waveform Visualization System using Gherkin syntax. These specifications define the expected behavior of the system from a user's perspective and serve as acceptance criteria for implementation.

---

## Feature: Fluid Waveform Rendering

As a user, I want to see a fluid waveform animation during recording so that I have visual feedback on audio capture.

### Background
```gherkin
Given the app is in recording state
And the capsule view is visible
```

### Scenario: Display fluid waveform during recording
```gherkin
When the user starts recording audio
Then the waveform visualization should appear in the capsule
And the waveform should use Canvas-based rendering
And the waveform should display 20 vertical bars by default
And each bar should have rounded corners for fluid appearance
```

**Test Strategy:**
- Unit test: Verify `WaveformView` renders with Canvas
- UI test: Capture screenshot of capsule during recording, verify waveform presence
- Manual test: Visual confirmation of Canvas rendering vs legacy view

---

### Scenario: Waveform responds to audio levels in real-time
```gherkin
Given the waveform is displayed
When the AudioLevelMonitor publishes a new audio level
Then the waveform bars should update within 50ms
And the bar heights should reflect the amplitude of the audio signal
And the update should not cause frame drops or stuttering
```

**Test Strategy:**
- Unit test: Mock `AudioLevelMonitor` with predefined levels, verify bar height calculations
- Performance test: Measure update latency from level publish to render completion
- Integration test: Connect real audio source, verify responsiveness

---

### Scenario: Waveform animates smoothly at 60fps
```gherkin
Given the waveform is active
When audio levels are changing continuously
Then the animation should maintain 60 frames per second
And the TimelineView should drive the animation updates
And no individual frame should take longer than 16.67ms to render
```

**Test Strategy:**
- Performance test: Use XCTMetric to measure frame rate during 30-second recording
- Unit test: Verify TimelineView.update() triggers canvas redraw
- Profiling: Check for dropped frames using Instruments

---

## Feature: Style Architecture

As a developer, I want multiple waveform styles to be architecturally supported so that future style variations can be added without refactoring.

### Scenario: Multiple waveform styles are supported
```gherkin
Given the waveform style architecture is implemented
When a new style is added conforming to WaveformStyle protocol
Then the system should recognize the new style
And the style should provide bar color, spacing, and animation parameters
And existing styles should remain unaffected
```

**Test Strategy:**
- Unit test: Create mock style, verify protocol conformance
- Unit test: Verify all built-in styles conform to WaveformStyle
- Regression test: Ensure adding new style doesn't break existing ones

---

### Scenario: Style can be selected at runtime
```gherkin
Given multiple waveform styles are available
When the application requests a specific style by identifier
Then the correct style implementation should be returned
And the waveform view should immediately switch to the new style
And the transition should be smooth without visual artifacts
```

**Test Strategy:**
- Unit test: Verify style registry returns correct style for identifier
- UI test: Switch styles mid-recording, verify visual change
- Integration test: Verify style persists across app restarts (via settings)

---

### Scenario: Default style is Fluid Waveform
```gherkin
Given the waveform visualization is initialized
When no specific style has been selected
Then the default style should be Fluid Waveform
And the default style should use gradient colors
And the default style should have smooth interpolation between updates
```

**Test Strategy:**
- Unit test: Verify default style identifier matches FluidWaveformStyle
- UI test: Fresh install, start recording, verify fluid appearance
- Snapshot test: Compare default style against reference image

---

## Feature: Performance

As a user, I want the waveform to animate smoothly without impacting system performance.

### Scenario: Waveform renders without blocking main thread
```gherkin
Given the waveform is actively animating
When audio processing occurs simultaneously
Then the main thread should not be blocked
And UI interactions should remain responsive
And the waveform animation should continue uninterrupted
```

**Test Strategy:**
- Performance test: Measure main thread CPU usage during recording
- Unit test: Verify Canvas drawing happens off-main-thread where possible
- Stress test: Simulate high CPU load, verify waveform continues

---

### Scenario: Memory usage remains constant during recording
```gherkin
Given the waveform has been animating for 5 minutes
When memory usage is measured
Then there should be no memory leaks
And memory usage should not grow linearly with time
And peak memory should remain under 10MB for waveform component
```

**Test Strategy:**
- Memory test: Use Xcode Memory Graph to check for leaks
- Performance test: Record 5-minute session, track memory growth
- Unit test: Verify no retain cycles in TimelineView or Canvas callbacks

---

### Scenario: Animation continues during audio processing
```gherkin
Given the waveform is animating
When transcription processing begins
Then the waveform animation should continue at 60fps
And the audio level monitoring should not be interrupted
And the UI should show both waveform and processing indicator
```

**Test Strategy:**
- Integration test: Trigger transcription while recording, verify animation continues
- Performance test: Measure frame rate during transcription processing
- Unit test: Verify audio level publisher operates on separate queue from transcription

---

## Feature: Integration

As a user, I want the waveform to integrate seamlessly with the existing capsule interface.

### Background
```gherkin
Given the capsule window is configured with nonactivatingPanel style
And the capsule can become key window for input events
```

### Scenario: Waveform displays in capsule during recording state
```gherkin
Given the app is in idle state showing the capsule
When the user initiates recording
Then the capsule should transition to recording state
And the waveform visualization should appear inside the capsule
And the waveform should be centered vertically in the capsule
And the waveform width should adapt to capsule size
```

**Test Strategy:**
- UI test: Verify waveform appears only in .recording state
- Layout test: Check constraints/adaptive sizing in different capsule sizes
- Manual test: Visual confirmation of positioning

---

### Scenario: Waveform transitions smoothly when recording stops
```gherkin
Given the waveform is actively animating in the capsule
When the user stops recording
Then the waveform should fade out over 200ms
And the capsule should transition to processing state
And the transition should not show any visual glitches
```

**Test Strategy:**
- UI test: Measure transition duration, verify 200ms fade
- Animation test: Verify smooth interpolation from full opacity to zero
- Regression test: Ensure no stuck frames or abrupt disappearance

---

### Scenario: Preview renders waveform with mock data
```gherkin
Given the developer is viewing SwiftUI preview
When the preview canvas displays WaveformView
Then the waveform should render with simulated audio levels
And the preview should show animated bars without requiring actual audio input
And the preview should demonstrate the default style
```

**Test Strategy:**
- Preview validation: Verify preview renders without errors
- Design review: Confirm preview shows representative animation
- Documentation: Include preview code as usage example

---

## Edge Cases

### Scenario: Waveform displays when audio level is zero
```gherkin
Given the microphone is muted or no audio is detected
When the waveform is displayed
Then all bars should show minimum height (not disappear completely)
And the waveform should indicate "silence" visually
And the animation should continue (not freeze)
```

**Test Strategy:**
- Unit test: Input level = 0, verify bars render at minimum height
- UI test: Screenshot comparison for silence state
- Edge case test: Transition from sound to silence, verify smooth decay

---

### Scenario: Waveform handles maximum audio level gracefully
```gherkin
Given the audio input is at maximum level (clipping)
When the waveform renders
Then bars should cap at maximum display height
And the waveform should not overflow its container
And no exception should be thrown
```

**Test Strategy:**
- Unit test: Input level = 1.0 (max), verify clamping logic
- Stress test: Rapid fluctuations between 0 and 1, verify stability
- Bounds test: Verify CGFloat infinity handling if present

---

### Scenario: Waveform recovers from audio interruption
```gherkin
Given the waveform is actively animating
When the audio session is interrupted (e.g., phone call, Siri)
Then the waveform should pause gracefully
And when the interruption ends
Then the waveform should resume animation automatically
And the transition should be smooth
```

**Test Strategy:**
- Integration test: Simulate audio session interruption
- State test: Verify waveform state machine handles .interrupted
- Recovery test: Verify automatic resumption after interruption ends

---

## Implementation Notes

### Key Components to Test

1. **WaveformView**: SwiftUI view using TimelineView + Canvas
2. **WaveformStyle Protocol**: Defines style interface
3. **FluidWaveformStyle**: Default implementation
4. **AudioLevelMonitor**: Publisher of audio level updates
5. **WaveformRenderer**: Handles Canvas drawing operations

### Test Data Requirements

```swift
// Mock audio levels for testing
let testLevels: [Float] = [
    0.0,      // Silence
    0.25,     // Quiet
    0.5,      // Normal
    0.75,     // Loud
    1.0,      // Maximum
    0.8, 0.6, 0.4, 0.2, 0.1  // Decay pattern
]
```

### Accessibility Considerations

```gherkin
Scenario: Waveform is accessible to VoiceOver users
Given VoiceOver is enabled
When the waveform is displayed
Then VoiceOver should announce "Recording in progress"
And VoiceOver should indicate audio activity level
And the waveform should not trap focus
```

---

## Appendix: Gherkin Reference

### Keywords Used
- **Feature**: High-level description of functionality
- **Background**: Steps common to all scenarios in a feature
- **Scenario**: Concrete example of system behavior
- **Given**: Precondition or initial context
- **When**: Action or event that triggers behavior
- **Then**: Expected outcome or observable result
- **And/But**: Continuation of previous step

### Naming Conventions
- Feature names: Noun phrase describing capability
- Scenario names: Verb phrase describing specific behavior
- Step definitions: Should be reusable across scenarios
