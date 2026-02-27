# Waveform Visualization Design

**Date:** 2026-02-27
**Status:** Draft
**Author:** Claude Code

---

## Context & Requirements

### Current Implementation

The existing waveform visualization uses a simple HStack with 20 fixed bars:

```swift
HStack(spacing: 4) {
    ForEach(0..<20) { index in
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(width: 4, height: barHeights[index])
    }
}
```

### Problems Identified

1. **Performance Issues**
   - SwiftUI view tree updates for every audio level change (60+ times/second)
   - State-driven animation causes frame drops during heavy transcription work
   - Memory pressure from repeated view reconstruction

2. **Aesthetic Limitations**
   - Discrete bars feel mechanical, not fluid
   - No visual connection to Apple's design language
   - Static appearance lacks the "living" quality of Siri's waveform

3. **Extensibility Concerns**
   - Hardcoded bar count and styling
   - No clean path for user customization via Settings
   - Style changes require view hierarchy modifications

### Goals

| Priority | Goal |
|----------|------|
| P0 | Fluid, organic waveform animation at 60fps |
| P0 | Canvas-based rendering for GPU acceleration |
| P1 | Architecture supporting multiple renderer styles |
| P1 | Clean integration point for future Settings UI |
| P2 | Apple-like elegance matching system aesthetics |

---

## Proposed Solution Overview

### High-Level Architecture

Replace the state-driven HStack with a **TimelineView-driven Canvas system** that separates data acquisition from rendering through a protocol-based abstraction layer.

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ AudioLevelMonitor│────▶│ WaveformRenderer │────▶│      Canvas     │
│  (Data Source)   │     │   (Protocol)     │     │  (GPU Rendering)│
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                ▲
                        ┌───────┴───────┐
                        ▼               ▼
                ┌──────────────┐ ┌──────────────┐
                │ FluidRenderer│ │ BarsRenderer │
                │ (Siri-like)  │ │ (Legacy)     │
                └──────────────┘ └──────────────┘
```

### Key Technologies

| Technology | Purpose |
|------------|---------|
| `TimelineView` | V-synced animation scheduling without state updates |
| `Canvas` | Direct GPU-accelerated drawing |
| `WaveformRenderer` protocol | Abstraction enabling style swapping |
| `AudioLevelMonitor` | Real-time audio level sampling |

### Fluid Waveform Approach

The Siri-like fluid effect is achieved through **three-layer sine wave叠加**:

1. **Primary Wave**: Base amplitude following audio levels with smooth interpolation
2. **Secondary Wave**: Higher frequency, lower amplitude for texture
3. **Tertiary Wave**: Slow-moving phase shift creating organic motion

Combined formula:
```swift
let y = sin(x * frequency1 + phase1) * amplitude1 +
        sin(x * frequency2 + phase2) * amplitude2 * 0.5 +
        sin(x * frequency3 + time * 0.5) * amplitude3 * 0.3
```

---

## Detailed Design

### Component Diagram

```
Presentation Layer
├── WaveformView (TimelineView container)
│   └── Canvas (rendering surface)
│       └── currentRenderer.draw(context: bounds: audioLevels:)
│
├── Renderer Protocols
│   ├── WaveformRenderer (base protocol)
│   ├── FluidWaveformRenderer (Siri-like)
│   └── BarWaveformRenderer (legacy compatibility)
│
└── Settings Integration Point
    └── WaveformStyle (enum, UserDefaults-backed)

Domain Layer
└── AudioLevelMonitor
    ├── AVAudioEngine tap
    ├── Ring buffer (last 60 samples)
    └── Publishers for real-time updates
```

### Data Flow

```
Audio Tap Callback
        │
        ▼
┌─────────────────┐
│ Level Calculator│─── Convert PCM buffer to dB
└─────────────────┘
        │
        ▼
┌─────────────────┐
│  Ring Buffer    │─── Store last 60 samples (1 second @ 60fps)
│  (fixed size)   │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ TimelineView    │─── V-sync display update
│   DisplayLink   │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ Canvas.onChange │─── Read buffer, no copy
└─────────────────┘
        │
        ▼
┌─────────────────┐
│   Renderer      │─── Draw wave/path/shape
│   .draw()       │
└─────────────────┘
```

### Style Selection Architecture

For future Settings integration, the architecture supports runtime renderer switching:

```swift
// Domain/Entities/WaveformStyle.swift
enum WaveformStyle: String, CaseIterable, Sendable {
    case fluid = "fluid"
    case bars = "bars"
    case particles = "particles" // Future
    case circular = "circular"   // Future
}

// Factory for renderer creation
struct WaveformRendererFactory {
    static func makeRenderer(for style: WaveformStyle) -> WaveformRenderer {
        switch style {
        case .fluid: return FluidWaveformRenderer()
        case .bars: return BarWaveformRenderer()
        default: return FluidWaveformRenderer()
        }
    }
}
```

---

## Design Documents

- [BDD Specifications](./bdd-specs.md) - Behavior scenarios and testing strategy
- [Architecture](./architecture.md) - System architecture and component details
- [Best Practices](./best-practices.md) - Performance, security, and code quality guidelines

---

## Success Criteria

### Performance Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Animation Frame Rate | >= 60fps | CADisplayLink callback timing |
| CPU Usage | < 5% on M1 Mac | Activity Monitor during recording |
| Memory Growth | Zero growth over 10min | Xcode Memory Graph |
| Main Thread Blocking | None | Instruments Time Profiler |

### Code Quality

| Criterion | Target |
|-----------|--------|
| New Renderer LOC | < 100 lines for basic implementation |
| Test Coverage | > 90% for new components |
| Backward Compatibility | All existing tests pass |
| Build Time Impact | < 5% increase |

### User Experience

| Criterion | Validation |
|-----------|------------|
| Visual Smoothness | No dropped frames during 60s recording |
| Style Switching | Instant, no restart required |
| Accessibility | VoiceOver labels for style selection |

---

## Future Extensions

### Phase 1: Settings Integration (Post-MVP)

```swift
// Settings/WaveformSettingsView.swift
struct WaveformSettingsView: View {
    @AppStorage("waveformStyle") private var style: WaveformStyle = .fluid

    var body: some View {
        Picker("Visualization Style", selection: $style) {
            ForEach(WaveformStyle.allCases, id: \.self) { style in
                Text(style.displayName).tag(style)
            }
        }
    }
}
```

### Phase 2: Additional Renderers

| Renderer | Description | Complexity |
|----------|-------------|------------|
| Particles | Floating dots responding to amplitude | Medium |
| Circular | Radial waveform from center | Low |
| Frequency Bands | FFT-based multi-band display | High |
| Minimalist | Single line, maximum simplicity | Low |

### Phase 3: Advanced Features

- **Color Themes**: Dynamic gradient based on app accent color
- **Sensitivity Adjustment**: User-controlled response to audio levels
- **Export Animation**: Record waveform as video/gif
- **Haptic Feedback**: Tactile response synchronized with peaks

---

## References

- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [CADisplayLink Best Practices](https://developer.apple.com/documentation/quartzcore/cadisplaylink)
- [Core Audio AudioTap](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Siri Waveform Analysis](https://www.reddit.com/r/iOSProgramming/comments/sirilike_waveform/)
