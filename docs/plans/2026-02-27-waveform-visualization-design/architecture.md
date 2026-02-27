# Waveform Visualization Architecture

## Overview

This document describes the architecture for a high-performance waveform visualization system using SwiftUI Canvas rendering. The design replaces the current 20-view HStack implementation with a GPU-accelerated single-pass rendering approach.

## Current Implementation Analysis

The existing waveform visualization in `Capsule/WaveformView.swift` uses:

```swift
HStack(spacing: AppSize.waveformBarSpacing) {
    ForEach(audioProvider.levels.indices, id: \.self) { index in
        WaveformBar(level: audioProvider.levels[index])  // 20 individual Views
    }
}
```

**Problems with this approach:**
1. **20 View instances** created every render cycle
2. Each `WaveformBar` triggers layout and animation independently
3. High CPU overhead from SwiftUI's diffing engine
4. Memory pressure from view hierarchy
5. Animation conflicts between `.animation(.linear(duration: 0.05), value: level)` calls

## Proposed Architecture

### Layer Structure Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│                                                              │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ WaveformContainer   │─────▶│ TimelineView(.animation) │  │
│  │     View            │      └────────────┬─────────────┘  │
│  └─────────────────────┘                   │                │
│           │                                ▼                │
│           │                      ┌─────────────────────┐    │
│           │                      │       Canvas        │    │
│           │                      │  (GPU Rendering)    │    │
│           │                      └──────────┬──────────┘    │
│           │                                 │               │
│           │         ┌───────────────────────┴───────┐       │
│           │         ▼                               ▼       │
│           │  ┌──────────────┐              ┌──────────────┐  │
│           └──│   Fluid      │              │   Classic    │  │
│              │ Waveform     │              │  Bar Style   │  │
│              │ Renderer     │              │   Renderer   │  │
│              └──────────────┘              └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│                                                              │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ AudioLevelProviding │◀─────│    AudioLevelMonitor     │  │
│  │     Protocol        │      │   (Existing, unchanged)  │  │
│  └─────────────────────┘      └──────────────────────────┘  │
│                                                              │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │  WaveformRendering  │◀─────│   WaveformStyle Enum     │  │
│  │     Protocol        │      │  (bar, fluid, disabled)  │  │
│  └─────────────────────┘      └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Audio Input → AVAudioEngine → AudioLevelMonitor → [CGFloat] levels
                                                       │
                                                       ▼
TimelineView(.animation) ──────────────────────▶ Canvas.render()
                                                       │
                                          ┌────────────┴────────────┐
                                          ▼                         ▼
                                   FluidRenderer              BarRenderer
                                   (Sine wave overlay)         (Classic bars)
```

## Protocol Design

### WaveformRendering Protocol

```swift
/// Protocol for waveform renderers that draw audio visualization
/// Implementations use Canvas for GPU-accelerated rendering
protocol WaveformRendering {
    /// Render the waveform into the provided GraphicsContext
    /// - Parameters:
    ///   - context: The GraphicsContext to draw into
    ///   - size: The available canvas size
    ///   - levels: Array of normalized audio levels (0.0...1.0)
    ///   - time: Current animation timestamp for phase calculations
    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [CGFloat],
        time: Date
    )

    /// Calculate the optimal bar count based on available width
    /// - Parameter width: Available width in points
    /// - Returns: Number of bars/samples to display
    func barCount(for width: CGFloat) -> Int
}

extension WaveformRendering {
    /// Default implementation: calculate bar count based on fixed width
    func barCount(for width: CGFloat) -> Int {
        let barWidth: CGFloat = 3
        let spacing: CGFloat = 2
        return max(10, Int(width / (barWidth + spacing)))
    }
}
```

### WaveformStyle Enum

```swift
/// Defines available waveform visualization styles
enum WaveformStyle: String, CaseIterable, Identifiable {
    case bar      // Classic bar style (current implementation)
    case fluid    // Organic sine wave overlay
    case disabled // No visualization

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bar: return "Bar"
        case .fluid: return "Fluid"
        case .disabled: return "Off"
        }
    }

    /// Create appropriate renderer for this style
    func makeRenderer() -> WaveformRendering? {
        switch self {
        case .bar:
            return BarWaveformRenderer()
        case .fluid:
            return FluidWaveformRenderer()
        case .disabled:
            return nil
        }
    }
}
```

## Renderer Implementations

### FluidWaveformRenderer

Uses three-layer sine wave overlay for organic fluid effect:

```swift
import SwiftUI

/// Renders an organic fluid waveform using overlapping sine waves
struct FluidWaveformRenderer: WaveformRendering {

    // MARK: - Configuration

    /// Primary wave amplitude multiplier
    private let primaryAmplitude: CGFloat = 1.0

    /// Secondary wave for texture (higher frequency, lower amplitude)
    private let secondaryAmplitude: CGFloat = 0.3
    private let secondaryFrequency: CGFloat = 2.5

    /// Tertiary wave for micro-detail
    private let tertiaryAmplitude: CGFloat = 0.15
    private let tertiaryFrequency: CGFloat = 5.0

    /// Wave speed (cycles per second)
    private let waveSpeed: CGFloat = 1.2

    /// Smoothing factor for level transitions (0...1)
    private let smoothingFactor: CGFloat = 0.3

    // MARK: - State

    /// Smoothed levels to prevent jarring jumps
    private var smoothedLevels: [CGFloat] = []

    // MARK: - WaveformRendering

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [CGFloat],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        // Initialize or resize smoothed levels
        if smoothedLevels.count != levels.count {
            smoothedLevels = levels
        }

        // Apply exponential smoothing
        for i in levels.indices {
            smoothedLevels[i] = smoothedLevels[i] * (1 - smoothingFactor) + levels[i] * smoothingFactor
        }

        let barCount = levels.count
        let barWidth = size.width / CGFloat(barCount)
        let centerY = size.height / 2
        let phase = CGFloat(time.timeIntervalSince1970) * waveSpeed * 2 * .pi

        // Draw each bar as a rounded rectangle with fluid height
        for i in 0..<barCount {
            let x = CGFloat(i) * barWidth + barWidth / 2
            let baseLevel = smoothedLevels[i]

            // Calculate fluid height using three sine waves
            let positionFactor = CGFloat(i) / CGFloat(barCount - 1)  // 0...1 across width

            // Primary wave: slow roll across the display
            let primaryWave = sin(positionFactor * .pi * 2 + phase)

            // Secondary wave: adds texture
            let secondaryWave = sin(positionFactor * .pi * 2 * secondaryFrequency + phase * 1.3)

            // Tertiary wave: micro-detail
            let tertiaryWave = sin(positionFactor * .pi * 2 * tertiaryFrequency + phase * 0.7)

            // Combine waves with decreasing amplitude
            let waveMultiplier = primaryWave * primaryAmplitude +
                                secondaryWave * secondaryAmplitude +
                                tertiaryWave * tertiaryAmplitude

            // Normalize to positive range and apply level
            let normalizedWave = (waveMultiplier + 2) / 4  // Maps -2...2 to 0...1 roughly
            let fluidHeight = baseLevel * normalizedWave * size.height

            // Draw the bar
            let rect = CGRect(
                x: x - barWidth * 0.4,
                y: centerY - fluidHeight / 2,
                width: barWidth * 0.8,
                height: fluidHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.4)

            // Gradient opacity based on level
            let opacity = 0.5 + baseLevel * 0.5
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }
}
```

### BarWaveformRenderer

Classic bar style matching current visual design:

```swift
import SwiftUI

/// Renders classic bar-style waveform
struct BarWaveformRenderer: WaveformRendering {

    /// Minimum bar height as ratio of container
    private let minHeightRatio: CGFloat = 0.1

    /// Corner radius ratio relative to bar width
    private let cornerRadiusRatio: CGFloat = 0.5

    /// Bar fill ratio (0...1) leaving gaps between bars
    private let barFillRatio: CGFloat = 0.8

    func render(
        context: GraphicsContext,
        size: CGSize,
        levels: [CGFloat],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        let barCount = levels.count
        let barWidth = size.width / CGFloat(barCount)
        let cornerRadius = barWidth * cornerRadiusRatio

        for i in 0..<barCount {
            let level = max(minHeightRatio, levels[i])
            let barHeight = max(barWidth, size.height * level)

            let x = CGFloat(i) * barWidth + (barWidth * (1 - barFillRatio)) / 2
            let y = (size.height - barHeight) / 2

            let rect = CGRect(
                x: x,
                y: y,
                width: barWidth * barFillRatio,
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

            // Opacity varies slightly with level for depth
            let opacity = 0.8 + level * 0.2
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }
}
```

## Integration Points

### WaveformContainerView

Replaces the current `WaveformView`:

```swift
import SwiftUI

/// Container view for waveform visualization with style selection support
struct WaveformContainerView: View {

    // MARK: - Dependencies

    private let audioProvider: AudioLevelProviding
    private let style: WaveformStyle

    // MARK: - Initialization

    init(
        audioProvider: AudioLevelProviding,
        style: WaveformStyle = .fluid
    ) {
        self.audioProvider = audioProvider
        self.style = style
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60, paused: false)) { timeline in
            Canvas { context, size in
                guard let renderer = style.makeRenderer() else { return }
                renderer.render(
                    context: context,
                    size: size,
                    levels: audioProvider.levels,
                    time: timeline.date
                )
            }
        }
    }
}

// MARK: - Preview Support

#Preview("Fluid Style") {
    WaveformContainerView(
        audioProvider: MockAudioProvider(),
        style: .fluid
    )
    .frame(width: 128, height: 24)
    .background(Color.black)
}

#Preview("Bar Style") {
    WaveformContainerView(
        audioProvider: MockAudioProvider(),
        style: .bar
    )
    .frame(width: 128, height: 24)
    .background(Color.black)
}

// MARK: - Mock Provider

private final class MockAudioProvider: AudioLevelProviding {
    var levels: [CGFloat] = Array(repeating: 0.5, count: 20)
    func start() {}
    func stop() {}
}
```

### CapsuleView Integration

Update `CapsuleView.swift` to use new container:

```swift
@ViewBuilder
private var content: some View {
    switch state.capsuleState {
    case .recording:
        WaveformContainerView(
            audioProvider: audioMonitor,
            style: .fluid  // Or read from settings
        )
        .frame(width: capsuleWidth - 32)

    // ... other cases unchanged
    }
}
```

### Settings Integration (Future)

For future Settings panel integration:

```swift
@MainActor
@Observable
final class WaveformSettings {
    var selectedStyle: WaveformStyle {
        didSet {
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: "waveformStyle")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "waveformStyle") ?? ""
        self.selectedStyle = WaveformStyle(rawValue: saved) ?? .fluid
    }
}

// Usage in CapsuleView
struct CapsuleView: View {
    @Environment(WaveformSettings.self) private var waveformSettings

    // In body:
    WaveformContainerView(
        audioProvider: audioMonitor,
        style: waveformSettings.selectedStyle
    )
}
```

## Performance Considerations

### Why Canvas is Better Than Individual Views

| Aspect | HStack + 20 Views | Canvas |
|--------|------------------|---------|
| View Count | 20+ instances | 1 instance |
| Layout Pass | O(n) layout calculations | Single bounds check |
| Rendering | Multiple layer compositing | Single GPU pass |
| Animation | 20 independent animations | Phase parameter interpolation |
| Memory | View tree overhead | Minimal state |
| Threading | Main thread layout | GPU-bound rendering |

### TimelineView Optimization

```swift
TimelineView(.animation(minimumInterval: 1/60, paused: false))
```

- `minimumInterval: 1/60`: Caps at display refresh rate (60fps)
- `paused: false`: Always running during recording
- Does NOT trigger SwiftUI view body re-evaluation
- Only calls Canvas closure with new timestamp
- Phase calculation happens inside renderer, not causing view updates

### Avoiding GeometryReader in Animation Path

**DON'T:**
```swift
GeometryReader { geo in
    Canvas { context, size in
        // This re-evaluates when parent changes
    }
}
```

**DO:**
```swift
Canvas { context, size in
    // Size comes from Canvas itself, stable across frames
}
.frame(width: fixedWidth, height: fixedHeight)  // Fixed size from parent
```

### Memory Efficiency

```swift
struct FluidWaveformRenderer: WaveformRendering {
    // Reuse array instead of allocating each frame
    private var smoothedLevels: [CGFloat] = []

    func render(...) {
        // Resize only when needed, not every frame
        if smoothedLevels.count != levels.count {
            smoothedLevels = levels  // Single allocation
        }
        // ... mutate in place
    }
}
```

## File Organization

```
DIYTypeless/
├── Domain/
│   ├── Protocols/
│   │   ├── AudioLevelProviding.swift      (existing)
│   │   └── WaveformRendering.swift        (new)
│   └── Entities/
│       └── WaveformStyle.swift            (new)
├── Presentation/
│   ├── Components/
│   │   └── WaveformContainerView.swift    (new)
│   └── Renderers/
│       ├── FluidWaveformRenderer.swift    (new)
│       └── BarWaveformRenderer.swift      (new)
└── Capsule/
    ├── WaveformView.swift                 (delete after migration)
    ├── CapsuleView.swift                  (update)
    └── CapsuleWindow.swift                (unchanged)
```

## Migration Plan

1. **Phase 1**: Create new protocols and renderers (no UI changes)
2. **Phase 2**: Add `WaveformContainerView` alongside existing `WaveformView`
3. **Phase 3**: Update `CapsuleView` to use new container
4. **Phase 4**: Remove old `WaveformView.swift`
5. **Phase 5**: Add Settings integration for style selection

## Testing Strategy

```swift
import XCTest
@testable import DIYTypeless

final class FluidWaveformRendererTests: XCTestCase {
    func testRenderDoesNotCrashWithEmptyLevels() {
        let renderer = FluidWaveformRenderer()
        let context = GraphicsContext(...)
        renderer.render(context: context, size: CGSize(width: 100, height: 20), levels: [], time: Date())
    }

    func testRenderWithTypicalLevels() {
        let renderer = FluidWaveformRenderer()
        let context = GraphicsContext(...)
        let levels = Array(repeating: 0.5, count: 20)
        renderer.render(context: context, size: CGSize(width: 128, height: 24), levels: levels, time: Date())
    }
}

final class WaveformStyleTests: XCTestCase {
    func testAllStylesHaveRenderers() {
        for style in WaveformStyle.allCases where style != .disabled {
            XCTAssertNotNil(style.makeRenderer(), "Style \(style) should have a renderer")
        }
    }

    func testDisabledStyleReturnsNilRenderer() {
        XCTAssertNil(WaveformStyle.disabled.makeRenderer())
    }
}
```

## References

- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [TimelineView Animation Scheduler](https://developer.apple.com/documentation/swiftui/timelineview/animation)
- [WaveformScrubber Library Pattern](https://github.com/johnrogersnm/SwiftUI-WaveformScrubber)
- [Apple WWDC21: Direct and Reflective Graphics in SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10021/)
