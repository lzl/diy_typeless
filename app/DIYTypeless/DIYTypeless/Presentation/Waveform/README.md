# Waveform Visualization

## Overview

GPU-accelerated waveform visualization using TimelineView + Canvas for smooth 60fps animation.

## Architecture

```
Presentation Layer
├── WaveformContainerView (TimelineView + Canvas)
├── WaveformRendering Protocol
├── FluidWaveformRenderer (Sine wave style)
├── BarWaveformRenderer (Discrete bars style)
└── WaveformRendererFactory

Domain Layer
├── AudioLevelProviding Protocol
└── WaveformStyle Enum

Infrastructure Layer
└── AudioLevelMonitor (Actor with AsyncStream)
```

## Usage

### Basic Usage

```swift
WaveformContainerView(
    audioMonitor: audioLevelMonitor,
    style: .fluid
)
.frame(width: 200, height: 40)
```

### With Settings

```swift
@State private var settings = WaveformSettings()

WaveformContainerView(
    audioMonitor: audioMonitor,
    style: settings.selectedStyle
)
```

### Available Styles

- `.fluid` - Smooth sine wave animation with three-phase interference
- `.bars` - Discrete vertical bars
- `.disabled` - No visualization (returns nil renderer)

## Adding a New Style

1. **Create Renderer** conforming to `WaveformRendering`:
```swift
@MainActor
final class MyCustomRenderer: WaveformRendering {
    func render(context: GraphicsContext, size: CGSize, levels: [Double], time: Date) {
        // Custom rendering code
    }
}
```

2. **Add Style Case** to `WaveformStyle` enum:
```swift
enum WaveformStyle: String, CaseIterable {
    case fluid, bars, disabled
    case myCustom  // Add new case
}
```

3. **Update Factory** to create the new renderer:
```swift
static func makeRenderer(for style: WaveformStyle) -> WaveformRendering? {
    switch style {
    // ... existing cases
    case .myCustom:
        return MyCustomRenderer()
    }
}
```

## Performance

- **Frame Rate**: 60fps via TimelineView animation display link
- **CPU Usage**: < 5% on M1 Mac
- **Memory**: Constant memory usage (no growth over time)
- **Renderer Caching**: Renderer stored in `@State` to avoid recreation

## Key Design Decisions

### Canvas vs HStack

- **Canvas**: GPU-accelerated, single draw call, 60fps capable
- **HStack**: Multiple views, more overhead, harder to optimize

### Actor vs @MainActor for AudioLevelMonitor

- **Actor**: Audio processing happens off-main thread
- **AsyncStream**: Thread-safe communication to UI

### AnyObject Constraint on Protocols

Required for Swift 6 strict concurrency to prevent deinit crashes on `@MainActor` classes.

## Testing

### Test Files

- `WaveformRenderingTests.swift` - Protocol conformance tests
- `FluidWaveformRendererTests.swift` - Fluid renderer tests
- `BarWaveformRendererTests.swift` - Bar renderer tests
- `WaveformRendererFactoryTests.swift` - Factory method tests
- `WaveformContainerViewTests.swift` - Container view tests
- `WaveformSettingsTests.swift` - Settings persistence tests
- `WaveformPerformanceTests.swift` - Performance benchmarks
- `WaveformEdgeCaseTests.swift` - Edge case handling

### Running Tests

```bash
./scripts/dev-loop-build.sh --testing
```
