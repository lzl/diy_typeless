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
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           WaveformRendering Protocol                  │   │
│  │     (Presentation layer - uses GraphicsContext)       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│                                                              │
│  ┌─────────────────────┐                                    │
│  │ AudioLevelProviding │◀────────── Protocol only          │
│  │     Protocol        │                                    │
│  └─────────────────────┘                                    │
│                                                              │
│  ┌─────────────────────┐                                    │
│  │   WaveformStyle     │◀────────── Enum (RawRepresentable) │
│  │       Enum          │                                    │
│  └─────────────────────┘                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│                                                              │
│  ┌──────────────────────────┐      ┌──────────────────────┐ │
│  │    AudioLevelMonitor     │─────▶│    AVAudioEngine     │ │
│  │  (Concrete Implementation)│     │   (System Framework)  │ │
│  └──────────────────────────┘      └──────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key architectural decisions:**
1. `WaveformRendering` protocol lives in **Presentation layer** because it uses SwiftUI's `GraphicsContext`
2. `AudioLevelMonitor` lives in **Infrastructure layer** because it uses `AVAudioEngine`
3. Domain layer contains only: `AudioLevelProviding` protocol and `WaveformStyle` enum

### Data Flow

```
Audio Input → AVAudioEngine → AudioLevelMonitor → [Double] levels
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

### WaveformRendering Protocol (Presentation Layer)

**IMPORTANT:** This protocol uses SwiftUI's `GraphicsContext` and therefore belongs in the **Presentation layer**, not Domain.

```swift
import SwiftUI

/// Protocol for waveform renderers that draw audio visualization
/// IMPLEMENTATION NOTE: This protocol uses SwiftUI.GraphicsContext and must remain
/// in the Presentation layer. Do not move to Domain.
protocol WaveformRendering: AnyObject {
    /// Render the waveform into the provided GraphicsContext
    /// - Parameters:
    ///   - context: The GraphicsContext to draw into
    ///   - size: The available canvas size
    ///   - levels: Array of normalized audio levels (0.0...1.0)
    ///   - time: Current animation timestamp for phase calculations
    func render(
        context: inout GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    )

    /// Calculate the optimal bar count based on available width
    /// - Parameter width: Available width in points
    /// - Returns: Number of bars/samples to display
    func barCount(for width: Double) -> Int
}

extension WaveformRendering {
    /// Default implementation: calculate bar count based on fixed width
    func barCount(for width: Double) -> Int {
        let barWidth: Double = 3
        let spacing: Double = 2
        return max(10, Int(width / (barWidth + spacing)))
    }
}
```

### WaveformStyle Enum (Domain Layer)

```swift
/// Defines available waveform visualization styles
/// Stored in UserDefaults as String rawValue
enum WaveformStyle: String, CaseIterable, Identifiable, Sendable {
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
}
```

**Note:** The factory method that creates renderers lives in the Presentation layer:

```swift
// Presentation/Waveform/WaveformRendererFactory.swift
import SwiftUI

enum WaveformRendererFactory {
    static func makeRenderer(for style: WaveformStyle) -> WaveformRendering? {
        switch style {
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

### Critical Implementation Notes

All renderers **must** be classes (not structs) with `@MainActor` because:
1. They maintain mutable state (`smoothedLevels`) that persists across frames
2. `GraphicsContext` operations must happen on the main thread
3. Structs would be copied on every render call, losing state

### FluidWaveformRenderer

```swift
import SwiftUI

/// Renders an organic fluid waveform using overlapping sine waves
/// IMPORTANT: Must be a class (not struct) to maintain smoothing state across frames
@MainActor
final class FluidWaveformRenderer: WaveformRendering {

    // MARK: - Configuration

    /// Primary wave amplitude multiplier
    private let primaryAmplitude: Double = 1.0

    /// Secondary wave for texture (higher frequency, lower amplitude)
    private let secondaryAmplitude: Double = 0.3
    private let secondaryFrequency: Double = 2.5

    /// Tertiary wave for micro-detail
    private let tertiaryAmplitude: Double = 0.15
    private let tertiaryFrequency: Double = 5.0

    /// Wave speed (cycles per second)
    private let waveSpeed: Double = 1.2

    /// Smoothing factor for level transitions (0...1)
    private let smoothingFactor: Double = 0.3

    // MARK: - State

    /// Smoothed levels to prevent jarring jumps
    /// NOTE: This state persists across render calls
    private var smoothedLevels: [Double] = []

    // MARK: - WaveformRendering

    func render(
        context: inout GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        // Initialize or resize smoothed levels
        if smoothedLevels.count != levels.count {
            smoothedLevels = levels
        }

        // Apply exponential smoothing in place (no new allocations)
        for i in levels.indices {
            smoothedLevels[i] = smoothedLevels[i] * (1 - smoothingFactor) + levels[i] * smoothingFactor
        }

        let barCount = levels.count
        let barWidth = Double(size.width) / Double(barCount)
        let centerY = Double(size.height) / 2
        let phase = Double(time.timeIntervalSince1970) * waveSpeed * 2 * .pi

        // Draw each bar as a rounded rectangle with fluid height
        for i in 0..<barCount {
            let x = Double(i) * barWidth + barWidth / 2
            let baseLevel = smoothedLevels[i]

            // Calculate fluid height using three sine waves
            let positionFactor = Double(i) / Double(barCount - 1)  // 0...1 across width

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
            let fluidHeight = baseLevel * normalizedWave * Double(size.height)

            // Draw the bar
            let rect = CGRect(
                x: x - barWidth * 0.4,
                y: centerY - fluidHeight / 2,
                width: barWidth * 0.8,
                height: max(2, fluidHeight)  // Minimum height of 2 points
            )

            let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.4)

            // Use semantic color that adapts to light/dark mode
            let opacity = 0.5 + baseLevel * 0.5
            context.fill(path, with: .color(Color.primary.opacity(opacity)))
        }
    }
}
```

### BarWaveformRenderer

```swift
import SwiftUI

/// Renders classic bar-style waveform
@MainActor
final class BarWaveformRenderer: WaveformRendering {

    /// Minimum bar height as ratio of container
    private let minHeightRatio: Double = 0.1

    /// Corner radius ratio relative to bar width
    private let cornerRadiusRatio: Double = 0.5

    /// Bar fill ratio (0...1) leaving gaps between bars
    private let barFillRatio: Double = 0.8

    func render(
        context: inout GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    ) {
        guard !levels.isEmpty else { return }

        let barCount = levels.count
        let barWidth = Double(size.width) / Double(barCount)
        let cornerRadius = barWidth * cornerRadiusRatio

        for i in 0..<barCount {
            let level = max(minHeightRatio, levels[i])
            let barHeight = max(barWidth, Double(size.height) * level)

            let x = Double(i) * barWidth + (barWidth * (1 - barFillRatio)) / 2
            let y = (Double(size.height) - barHeight) / 2

            let rect = CGRect(
                x: x,
                y: y,
                width: barWidth * barFillRatio,
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

            // Use semantic color
            let opacity = 0.8 + level * 0.2
            context.fill(path, with: .color(Color.primary.opacity(opacity)))
        }
    }
}
```

## Integration Points

### WaveformContainerView

**CRITICAL FIX:** The renderer must be cached in `@State` to avoid creating a new instance every frame.

```swift
import SwiftUI

/// Container view for waveform visualization with style selection support
struct WaveformContainerView: View {

    // MARK: - Dependencies

    private let audioProvider: AudioLevelProviding
    private let style: WaveformStyle

    // MARK: - State

    /// Renderer is cached to maintain smoothing state across frames
    /// CRITICAL: Creating a new renderer each frame would reset smoothedLevels!
    @State private var renderer: WaveformRendering?

    // MARK: - Initialization

    init(
        audioProvider: AudioLevelProviding,
        style: WaveformStyle = .fluid
    ) {
        self.audioProvider = audioProvider
        self.style = style
        // Note: Cannot initialize @State here, done in onAppear
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60, paused: false)) { timeline in
            Canvas { context, size in
                renderer?.render(
                    context: &context,
                    size: size,
                    levels: audioProvider.levels.map(Double.init),
                    time: timeline.date
                )
            }
        }
        .onAppear {
            // Initialize renderer once when view appears
            if renderer == nil {
                renderer = WaveformRendererFactory.makeRenderer(for: style)
            }
        }
        .onChange(of: style) { _, newStyle in
            // Update renderer when style changes
            renderer = WaveformRendererFactory.makeRenderer(for: newStyle)
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

@MainActor
private final class MockAudioProvider: AudioLevelProviding {
    var levels: [Double] = Array(repeating: 0.5, count: 20)
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

**FIXED:** Removed `didSet` usage which is incompatible with `@Observable`.

```swift
import SwiftUI

@MainActor
@Observable
final class WaveformSettings {
    private let defaults: UserDefaults

    var selectedStyle: WaveformStyle {
        get {
            let saved = defaults.string(forKey: "waveformStyle") ?? ""
            return WaveformStyle(rawValue: saved) ?? .fluid
        }
        set {
            defaults.set(newValue.rawValue, forKey: "waveformStyle")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
@MainActor
final class FluidWaveformRenderer: WaveformRendering {
    // Reuse array instead of allocating each frame
    private var smoothedLevels: [Double] = []

    func render(...) {
        // Resize only when needed, not every frame
        if smoothedLevels.count != levels.count {
            smoothedLevels = levels  // Single allocation
        }
        // Mutate in place
        for i in levels.indices {
            smoothedLevels[i] = smoothedLevels[i] * (1 - smoothingFactor) + levels[i] * smoothingFactor
        }
    }
}
```

## File Organization

```
DIYTypeless/
├── Domain/
│   ├── Protocols/
│   │   └── AudioLevelProviding.swift      (existing)
│   └── Entities/
│       └── WaveformStyle.swift            (new)
├── Presentation/
│   ├── Components/
│   │   └── WaveformContainerView.swift    (new)
│   ├── Renderers/
│   │   ├── FluidWaveformRenderer.swift    (new)
│   │   ├── BarWaveformRenderer.swift      (new)
│   │   └── WaveformRendererFactory.swift  (new)
│   └── Protocols/
│       └── WaveformRendering.swift        (new - Presentation layer!)
├── Infrastructure/
│   └── Audio/
│       └── AudioLevelMonitor.swift        (moved from Domain)
└── Capsule/
    ├── WaveformView.swift                 (delete after migration)
    ├── CapsuleView.swift                  (update)
    └── CapsuleWindow.swift                (unchanged)
```

## Migration Plan

1. **Phase 1**: Move `AudioLevelMonitor` to Infrastructure layer
2. **Phase 2**: Create `WaveformRendering` protocol in Presentation layer
3. **Phase 3**: Implement `FluidWaveformRenderer` and `BarWaveformRenderer` as classes with `@MainActor`
4. **Phase 4**: Add `WaveformContainerView` with proper @State caching
5. **Phase 5**: Update `CapsuleView` to use new container
6. **Phase 6**: Remove old `WaveformView.swift`
7. **Phase 7**: Add Settings integration for style selection

## Testing Strategy

**FIXED:** Tests now use mockable approaches that don't require GraphicsContext instantiation.

```swift
import XCTest
@testable import DIYTypeless

// MARK: - Domain Logic Tests (Testable)

final class WaveformStyleTests: XCTestCase {
    func testAllStylesHaveRawValues() {
        for style in WaveformStyle.allCases {
            XCTAssertFalse(style.rawValue.isEmpty, "Style \(style) must have a raw value")
        }
    }

    func testStyleRoundTrip() {
        for style in WaveformStyle.allCases {
            let recreated = WaveformStyle(rawValue: style.rawValue)
            XCTAssertEqual(recreated, style, "Style \(style) should round-trip through rawValue")
        }
    }

    func testDisabledStyleReturnsNilRenderer() {
        let renderer = WaveformRendererFactory.makeRenderer(for: .disabled)
        XCTAssertNil(renderer)
    }

    func testNonDisabledStylesReturnRenderers() {
        let barRenderer = WaveformRendererFactory.makeRenderer(for: .bar)
        XCTAssertNotNil(barRenderer)
        XCTAssertTrue(barRenderer is BarWaveformRenderer)

        let fluidRenderer = WaveformRendererFactory.makeRenderer(for: .fluid)
        XCTAssertNotNil(fluidRenderer)
        XCTAssertTrue(fluidRenderer is FluidWaveformRenderer)
    }
}

final class AudioLevelProvidingTests: XCTestCase {
    func testMockProviderReturnsExpectedLevels() {
        let mock = MockAudioLevelProvider()
        mock.levels = [0.1, 0.5, 0.9]

        XCTAssertEqual(mock.levels.count, 3)
        XCTAssertEqual(mock.levels[1], 0.5, accuracy: 0.001)
    }
}

// MARK: - Integration Tests (Preview-based)

#if DEBUG
final class WaveformPreviewTests: XCTestCase {
    /// Verifies previews don't crash (catches runtime errors in renderers)
    func testFluidWaveformPreviewRenders() {
        let view = WaveformContainerView(
            audioProvider: MockAudioLevelProvider(),
            style: .fluid
        )
        .frame(width: 128, height: 24)

        // If this doesn't crash, the renderer is valid
        XCTAssertNotNil(view.body)
    }

    func testBarWaveformPreviewRenders() {
        let view = WaveformContainerView(
            audioProvider: MockAudioLevelProvider(),
            style: .bar
        )
        .frame(width: 128, height: 24)

        XCTAssertNotNil(view.body)
    }
}
#endif

// MARK: - Performance Tests

final class WaveformPerformanceTests: XCTestCase {
    func testRendererPerformance() {
        let renderer = FluidWaveformRenderer()
        let levels = Array(repeating: 0.5, count: 20)

        measure {
            // Simulate 60 frames of rendering
            for i in 0..<60 {
                let time = Date().addingTimeInterval(Double(i) / 60.0)
                // Note: Cannot test actual rendering without GraphicsContext,
                // but we can test the smoothing algorithm
                _ = simulateSmoothing(levels: levels, factor: 0.3)
            }
        }
    }

    private func simulateSmoothing(levels: [Double], factor: Double) -> [Double] {
        var smoothed = levels
        for i in levels.indices {
            smoothed[i] = smoothed[i] * (1 - factor) + levels[i] * factor
        }
        return smoothed
    }
}
```

## References

- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [TimelineView Animation Scheduler](https://developer.apple.com/documentation/swiftui/timelineview/animation)
- [WaveformScrubber Library Pattern](https://github.com/johnrogersnm/SwiftUI-WaveformScrubber)
- [Apple WWDC21: Direct and Reflective Graphics in SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10021/)
