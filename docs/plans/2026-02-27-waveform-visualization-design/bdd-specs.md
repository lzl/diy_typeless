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
And the waveform should use TimelineView for 60fps animation
And the renderer should be cached to maintain animation state
```

**Test Strategy:**
- Unit test: Verify `WaveformContainerView` uses TimelineView + Canvas
- Unit test: Verify renderer is cached in @State (not recreated each frame)
- UI test: Capture screenshot of capsule during recording, verify waveform presence
- Manual test: Visual confirmation of smooth 60fps animation vs legacy view

**Architecture Verification:**
- Verify `WaveformRendering` protocol is in Presentation layer
- Verify renderer is `@MainActor class` (not struct)
- Verify `AudioLevelMonitor` is in Infrastructure layer

---

### Scenario: Waveform responds to audio levels in real-time
```gherkin
Given the waveform is displayed
When the AudioLevelMonitor publishes a new audio level
Then the waveform bars should update within 50ms
And the bar heights should reflect the amplitude of the audio signal
And the update should not cause frame drops or stuttering
And the waveform should use Double (not CGFloat) for level calculations
```

**Test Strategy:**
- Unit test: Mock `AudioLevelProviding` with predefined Double levels, verify bar height calculations
- Performance test: Measure update latency from level publish to render completion
- Integration test: Connect real audio source, verify responsiveness
- Type safety test: Verify no CGFloat usage in Domain layer calculations

---

### Scenario: Waveform animates smoothly at 60fps
```gherkin
Given the waveform is active
When audio levels are changing continuously
Then the animation should maintain 60 frames per second
And the TimelineView should drive the animation updates
And no individual frame should take longer than 16.67ms to render
And the renderer state should persist across frames
```

**Test Strategy:**
- Performance test: Use XCTMetric to measure frame rate during 30-second recording
- Unit test: Verify TimelineView.animation triggers canvas redraw
- Profiling: Check for dropped frames using Instruments
- State test: Verify `smoothedLevels` array maintains values across render calls

---

## Feature: Clean Architecture Compliance

As a developer, I want the waveform system to follow Clean Architecture principles so that the codebase remains maintainable and testable.

### Background
```gherkin
Given the codebase follows Clean Architecture guidelines
And dependencies point inward toward Domain layer
```

### Scenario: WaveformRendering protocol is in Presentation layer
```gherkin
Given the WaveformRendering protocol is defined
When I check its file location
Then it should be in the Presentation/Protocols directory
And it should use GraphicsContext (SwiftUI type)
And it should NOT be in Domain layer
And Domain layer should have no SwiftUI imports
```

**Test Strategy:**
- Architecture test: Verify file location matches layer convention
- Import test: Verify Domain targets have no SwiftUI imports
- Protocol test: Verify WaveformRendering uses GraphicsContext

---

### Scenario: AudioLevelMonitor is in Infrastructure layer
```gherkin
Given the AudioLevelMonitor implementation exists
When I check its file location
Then it should be in the Infrastructure/Audio directory
And it should use AVAudioEngine
And it should conform to AudioLevelProviding protocol
And it should be marked as @MainActor or use proper isolation
```

**Test Strategy:**
- Architecture test: Verify file location in Infrastructure layer
- Protocol conformance test: Verify it implements AudioLevelProviding
- Import test: Verify it imports AVFoundation

---

### Scenario: Domain layer remains pure
```gherkin
Given the Domain layer contains waveform-related code
When I check for framework dependencies
Then there should be no SwiftUI imports
And there should be no AVFoundation imports
And there should be no CoreGraphics (CGFloat) usage
And only standard library types should be used (Double, not CGFloat)
```

**Test Strategy:**
- Import analysis: Verify Domain files only import Foundation
- Type safety test: Verify use of Double over CGFloat
- Protocol test: Verify AudioLevelProviding uses pure Swift types

---

## Feature: Style Architecture

As a developer, I want multiple waveform styles to be architecturally supported so that future style variations can be added without refactoring.

### Scenario: Multiple waveform styles are supported
```gherkin
Given the waveform style architecture is implemented
When a new style is added conforming to WaveformRendering protocol
Then the system should recognize the new style
And the style should be a @MainActor class (not struct)
And existing styles should remain unaffected
And the style enum should be Sendable for concurrency safety
```

**Test Strategy:**
- Unit test: Create mock renderer class, verify protocol conformance
- Unit test: Verify all built-in renderers are @MainActor classes
- Concurrency test: Verify WaveformStyle enum is Sendable
- Regression test: Ensure adding new style doesn't break existing ones

---

### Scenario: Style can be selected at runtime
```gherkin
Given multiple waveform styles are available
When the application requests a specific style by identifier
Then the WaveformRendererFactory should return the correct renderer
And the renderer should be cached in @State
And the waveform view should immediately switch to the new style
And the transition should be smooth without visual artifacts
```

**Test Strategy:**
- Unit test: Verify WaveformRendererFactory returns correct renderer for each style
- State test: Verify renderer is cached and not recreated on style change
- UI test: Switch styles mid-recording, verify visual change
- Integration test: Verify style change doesn't cause memory leaks

---

### Scenario: Default style is Fluid Waveform
```gherkin
Given the waveform visualization is initialized
When no specific style has been selected
Then the default style should be Fluid Waveform
And the default renderer should be FluidWaveformRenderer
And the FluidWaveformRenderer should maintain smoothing state
```

**Test Strategy:**
- Unit test: Verify default style identifier matches .fluid
- Unit test: Verify FluidWaveformRenderer is a class (not struct)
- State test: Verify smoothedLevels array persists across frames

---

## Feature: Renderer State Management

As a developer, I want renderers to maintain state across animation frames so that smoothing and visual effects work correctly.

### Scenario: Renderer state persists across frames
```gherkin
Given a FluidWaveformRenderer is active
When multiple animation frames are rendered
Then the smoothedLevels array should maintain values between frames
And the renderer should be the same instance (not recreated)
And exponential smoothing should produce gradual transitions
```

**Test Strategy:**
- State test: Verify renderer instance identity across render calls
- Algorithm test: Verify exponential smoothing formula produces expected values
- Integration test: Rapid level changes should show smooth transitions

---

### Scenario: Renderer handles empty levels gracefully
```gherkin
Given the waveform is rendering
When the levels array is empty
Then the renderer should return early without crashing
And the Canvas should remain empty
And no exception should be thrown
```

**Test Strategy:**
- Edge case test: Pass empty array to render(), verify no crash
- Edge case test: Pass array with all zeros, verify minimum height bars
- Fuzz test: Random input arrays of various sizes

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
And TimelineView should handle display link callbacks efficiently
```

**Test Strategy:**
- Performance test: Measure main thread CPU usage during recording
- Unit test: Verify Canvas drawing doesn't perform heavy computation
- Stress test: Simulate high CPU load, verify waveform continues

---

### Scenario: Memory usage remains constant during recording
```gherkin
Given the waveform has been animating for 5 minutes
When memory usage is measured
Then there should be no memory leaks
And memory usage should not grow linearly with time
And the renderer's smoothedLevels array size should remain constant
And peak memory should remain under 10MB for waveform component
```

**Test Strategy:**
- Memory test: Use Xcode Memory Graph to check for leaks
- Performance test: Record 5-minute session, track memory growth
- State test: Verify smoothedLevels.count remains constant after initial setup
- Unit test: Verify no retain cycles in TimelineView or renderer

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
- Unit test: Verify audio level publisher operates independently from transcription

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
And the renderer should not leak memory after transition
```

**Test Strategy:**
- UI test: Measure transition duration, verify 200ms fade
- Animation test: Verify smooth interpolation from full opacity to zero
- Memory test: Verify renderer is deallocated after view disappears

---

### Scenario: Preview renders waveform with mock data
```gherkin
Given the developer is viewing SwiftUI preview
When the preview canvas displays WaveformContainerView
Then the waveform should render with simulated audio levels
And the preview should use MockAudioLevelProvider
And the preview should demonstrate the default style
And the renderer should initialize correctly in preview context
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
And the smoothing algorithm should handle zero values
```

**Test Strategy:**
- Unit test: Input level = 0, verify bars render at minimum height
- UI test: Screenshot comparison for silence state
- Edge case test: Transition from sound to silence, verify smooth decay
- Algorithm test: Verify smoothing with zero input doesn't cause division by zero

---

### Scenario: Waveform handles maximum audio level gracefully
```gherkin
Given the audio input is at maximum level (clipping)
When the waveform renders
Then bars should cap at maximum display height
And the waveform should not overflow its container
And no exception should be thrown
And values should be clamped to valid range
```

**Test Strategy:**
- Unit test: Input level = 1.0 (max), verify clamping logic
- Stress test: Rapid fluctuations between 0 and 1, verify stability
- Bounds test: Verify Double infinity/NaN handling if present

---

### Scenario: Waveform recovers from audio interruption
```gherkin
Given the waveform is actively animating
When the audio session is interrupted (e.g., phone call, Siri)
Then the waveform should pause gracefully
And when the interruption ends
Then the waveform should resume animation automatically
And the renderer state should be preserved
```

**Test Strategy:**
- Integration test: Simulate audio session interruption
- State test: Verify waveform state machine handles .interrupted
- Recovery test: Verify automatic resumption after interruption ends
- State preservation: Verify smoothedLevels maintained across interruption

---

### Scenario: Renderer handles rapid style switches
```gherkin
Given the waveform is rendering with Fluid style
When the user rapidly switches between styles 10 times
Then each switch should complete successfully
And memory usage should not increase
And only the current renderer should be retained
```

**Test Strategy:**
- Stress test: Rapid style switching, verify no crashes
- Memory test: Verify old renderers are deallocated
- State test: Verify @State properly updates renderer reference

---

## Feature: Type Safety and Concurrency

As a developer, I want the waveform system to use proper types and concurrency primitives.

### Scenario: Domain layer uses Double (not CGFloat)
```gherkin
Given the AudioLevelProviding protocol is defined
When I check the levels array type
Then it should be [Double]
And it should NOT be [CGFloat]
And calculations should use Double throughout Domain layer
```

**Test Strategy:**
- Type check: Verify AudioLevelProviding.levels is [Double]
- Compile test: Verify no implicit CGFloat conversions in Domain
- Conversion test: Verify Presentation layer converts Double to CGFloat for Canvas

---

### Scenario: WaveformStyle is Sendable
```gherkin
Given the WaveformStyle enum is defined
When I check its conformance
Then it should conform to Sendable
And it should be safe to pass between actors
And all associated values should be Sendable
```

**Test Strategy:**
- Concurrency test: Verify Sendable conformance compiles
- Actor test: Pass WaveformStyle between @MainActor and background actors

---

### Scenario: @Observable without didSet
```gherkin
Given WaveformSettings uses @Observable
When properties are observed
Then it should NOT use didSet observers
And it should use computed properties for side effects
And state updates should propagate automatically
```

**Test Strategy:**
- Pattern test: Verify no didSet usage in @Observable classes
- Integration test: Verify settings changes propagate to views
- Performance test: Verify no infinite update loops

---

## Implementation Notes

### Key Components to Test

1. **WaveformContainerView**: SwiftUI view using TimelineView + Canvas
2. **WaveformRendering Protocol**: Presentation layer protocol using GraphicsContext
3. **FluidWaveformRenderer**: @MainActor class with state preservation
4. **BarWaveformRenderer**: @MainActor class for legacy style
5. **AudioLevelProviding**: Domain protocol using Double (not CGFloat)
6. **WaveformRendererFactory**: Creates renderers from WaveformStyle
7. **WaveformSettings**: @Observable without didSet

### Test Data Requirements

```swift
// Mock audio levels for testing - using Double (not CGFloat)
let testLevels: [Double] = [
    0.0,      // Silence
    0.25,     // Quiet
    0.5,      // Normal
    0.75,     // Loud
    1.0,      // Maximum
    0.8, 0.6, 0.4, 0.2, 0.1  // Decay pattern
]

// Edge case values
let edgeCases: [[Double]] = [
    [],                                    // Empty
    [0.0, 0.0, 0.0],                      // All silence
    [1.0, 1.0, 1.0],                      // All max
    Array(repeating: 0.5, count: 1000),   // Large array
    [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]       // Rapid alternation
]
```

### Architecture Test Checklist

- [ ] WaveformRendering is in Presentation/Protocols (not Domain)
- [ ] AudioLevelMonitor is in Infrastructure (not Domain)
- [ ] AudioLevelProviding is in Domain/Protocols
- [ ] WaveformStyle is in Domain/Entities and is Sendable
- [ ] All renderers are @MainActor classes (not structs)
- [ ] No CGFloat usage in Domain layer
- [ ] No SwiftUI imports in Domain layer
- [ ] No AVFoundation imports in Domain layer
- [ ] Renderer cached in @State (not recreated each frame)
- [ ] No didSet usage in @Observable classes

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
