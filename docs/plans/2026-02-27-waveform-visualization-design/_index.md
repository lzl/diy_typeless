# Waveform Visualization Design

**Date:** 2026-02-27
**Status:** Draft - Architecture Review Fixes Applied
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

4. **Architecture Issues** (from code review)
   - `GraphicsContext` (SwiftUI) incorrectly placed in Domain layer
   - `AudioLevelMonitor` (using AVAudioEngine) mixed with Domain protocols
   - Renderers implemented as structs lose state between frames
   - TimelineView creates new renderer each frame

### Goals

| Priority | Goal |
|----------|------|
| P0 | Fluid, organic waveform animation at 60fps |
| P0 | Canvas-based rendering for GPU acceleration |
| P0 | **Clean Architecture compliance** (fixed layering) |
| P1 | Architecture supporting multiple renderer styles |
| P1 | Clean integration point for future Settings UI |
| P2 | Apple-like elegance matching system aesthetics |

---

## Proposed Solution Overview

### High-Level Architecture

Replace the state-driven HStack with a **TimelineView-driven Canvas system** that properly separates concerns across architectural layers.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  WaveformRendering Protocol (uses GraphicsContext)   │   │
│  │  ┌──────────────────┐      ┌──────────────────┐     │   │
│  │  │FluidWaveformRenderer│   │BarWaveformRenderer│    │   │
│  │  │ (@MainActor class)  │   │ (@MainActor class)│    │   │
│  │  └──────────────────┘      └──────────────────┘     │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│                         │                                   │
│  ┌──────────────────────┴─────────────────────────────┐    │
│  │       WaveformContainerView (caches renderer)      │    │
│  │         TimelineView + Canvas (GPU rendering)      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ AudioLevelProviding │      │ WaveformStyle            │  │
│  │ Protocol (pure)     │      │ Enum (Sendable)          │  │
│  └─────────────────────┘      └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  ┌──────────────────────────┐      ┌──────────────────────┐ │
│  │    AudioLevelMonitor     │─────▶│    AVAudioEngine     │ │
│  │  (Concrete Implementation)│     │   (System Framework)  │ │
│  └──────────────────────────┘      └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Technologies

| Technology | Purpose |
|------------|---------|
| `TimelineView` | V-synced animation scheduling without state updates |
| `Canvas` | Direct GPU-accelerated drawing |
| `WaveformRendering` protocol | Presentation-layer abstraction |
| `@MainActor class` renderers | State preservation across frames |
| `@State` renderer caching | Prevent per-frame allocation |
| `AudioLevelMonitor` | Real-time audio level sampling (Infrastructure) |

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
├── WaveformContainerView (TimelineView container)
│   └── Canvas (rendering surface)
│       └── renderer.render(context:size:levels:time:) [cached in @State]
│
├── Renderers (all @MainActor classes)
│   ├── FluidWaveformRenderer (Siri-like, maintains smoothedLevels)
│   └── BarWaveformRenderer (legacy compatibility)
│
├── Protocols
│   └── WaveformRendering (uses GraphicsContext - Presentation layer only)
│
└── Factory
    └── WaveformRendererFactory (creates renderers from WaveformStyle)

Domain Layer
├── AudioLevelProviding (protocol, no implementation)
└── WaveformStyle (enum, Sendable, UserDefaults-compatible)

Infrastructure Layer
└── AudioLevelMonitor (implements AudioLevelProviding, uses AVAudioEngine)
```

### Data Flow

```
Audio Tap Callback (Infrastructure)
        │
        ▼
┌─────────────────┐
│ Level Calculator│─── Convert PCM buffer to normalized Double (0...1)
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ AudioLevelProviding
│  levels: [Double]  ◀── Domain protocol, Infrastructure implementation
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ TimelineView    │─── V-sync display update (60fps, no body re-eval)
│   DisplayLink   │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ Canvas          │─── Cached renderer.render() call
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ FluidRenderer   │─── Draw with preserved smoothing state
│ (class + @State)│
└─────────────────┘
```

### Style Selection Architecture

For future Settings integration:

```swift
// Domain/Entities/WaveformStyle.swift
enum WaveformStyle: String, CaseIterable, Sendable {
    case fluid = "fluid"
    case bars = "bars"
    case disabled = "disabled"
}

// Presentation/Waveform/WaveformRendererFactory.swift
@MainActor
enum WaveformRendererFactory {
    static func makeRenderer(for style: WaveformStyle) -> WaveformRendering? {
        switch style {
        case .fluid: return FluidWaveformRenderer()
        case .bars: return BarWaveformRenderer()
        case .disabled: return nil
        }
    }
}
```

### Critical Implementation Fixes (from Architecture Review)

**1. Layer Placement (FIXED)**
- `WaveformRendering` → **Presentation layer** (uses GraphicsContext)
- `AudioLevelMonitor` → **Infrastructure layer** (uses AVAudioEngine)
- Domain layer → Only `AudioLevelProviding` protocol and `WaveformStyle` enum

**2. Renderer State Management (FIXED)**
```swift
// BEFORE (reviewer flagged as broken)
struct FluidWaveformRenderer: WaveformRendering {
    private var smoothedLevels: [CGFloat] = []  // Lost every frame!
}

// AFTER (fixed)
@MainActor
final class FluidWaveformRenderer: WaveformRendering {
    private var smoothedLevels: [Double] = []   // Persists across frames
}
```

**3. Renderer Caching (FIXED)**
```swift
// BEFORE (reviewer flagged as broken)
var body: some View {
    TimelineView(...) { timeline in
        Canvas { context, size in
            let renderer = style.makeRenderer()  // NEW INSTANCE EVERY FRAME!
            renderer?.render(...)
        }
    }
}

// AFTER (fixed)
struct WaveformContainerView: View {
    @State private var renderer: WaveformRendering?  // Cached!

    var body: some View {
        TimelineView(...) { timeline in
            Canvas { context, size in
                renderer?.render(...)  // Reuses cached instance
            }
        }
        .onAppear {
            if renderer == nil {
                renderer = WaveformRendererFactory.makeRenderer(for: style)
            }
        }
    }
}
```

**4. @Observable without didSet (FIXED)**
```swift
// BEFORE (reviewer flagged as broken)
@Observable
final class WaveformSettings {
    var selectedStyle: WaveformStyle {
        didSet {  // ❌ didSet doesn't work with @Observable!
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: "waveformStyle")
        }
    }
}

// AFTER (fixed)
@Observable
final class WaveformSettings {
    var selectedStyle: WaveformStyle {
        get { /* read from UserDefaults */ }
        set { /* write to UserDefaults */ }
    }
}
```

**5. Type Safety (FIXED)**
```swift
// BEFORE
var levels: [CGFloat]  // CGFloat is platform-dependent

// AFTER
var levels: [Double]   // Double is standard, converted to CGFloat only in Canvas
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
| Architecture Compliance | All layers properly separated |
| Renderer LOC | < 100 lines for basic implementation |
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

## Changelog

### 2026-02-27 - Architecture Review Fixes

1. **Moved `WaveformRendering` to Presentation layer** - Uses GraphicsContext, not Domain-appropriate
2. **Moved `AudioLevelMonitor` to Infrastructure layer** - Uses AVAudioEngine, concrete implementation
3. **Changed renderers from struct to @MainActor class** - Fixes state loss between frames
4. **Added @State caching for renderer** - Prevents per-frame allocation
5. **Fixed @Observable didSet anti-pattern** - Use computed property with explicit get/set
6. **Replaced CGFloat with Double** - Standard types in Domain, platform types only in Presentation
7. **Fixed Sendable compliance** - Remove Timer from actor, use Task.sleep
8. **Added semantic color usage** - Color.primary instead of .white
9. **Fixed test strategy** - Mockable approaches, no GraphicsContext instantiation in unit tests

---

## References

- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [CADisplayLink Best Practices](https://developer.apple.com/documentation/quartzcore/cadisplaylink)
- [Core Audio AudioTap](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Clean Architecture for SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
- [SwiftUI @Observable Deep Dive](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
