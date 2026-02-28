# Waveform Visualization Best Practices

This document outlines best practices for implementing high-performance waveform visualization in SwiftUI, specifically designed for real-time audio level monitoring in macOS applications.

## 1. Performance Guidelines

### Why Canvas Beats HStack of Views

The performance difference between rendering approaches is staggering:

| Approach | Time to Render 10,000 Bars |
|----------|---------------------------|
| HStack with individual Views | ~5,000ms |
| Canvas drawing | ~10ms |
| **Improvement** | **50,000% faster** |

**Key insight:** Each SwiftUI View carries significant overhead - layout calculations, state management, and rendering pipeline costs. Canvas draws directly to a graphics context, bypassing the entire view hierarchy.

**DO:**
```swift
Canvas { context, size in
    // Draw all bars in a single pass
    for (index, level) in audioLevels.enumerated() {
        let barRect = CGRect(...)
        context.fill(Path(barRect), with: .color(barColor))
    }
}
```

**DON'T:**
```swift
HStack(spacing: 2) {
    ForEach(audioLevels, id: \.self) { level in
        Rectangle()
            .fill(barColor)
            .frame(height: level * maxHeight)
    }
}
```

### TimelineView vs Timer-Based Animation

Always use `TimelineView(.animation)` instead of `Timer` or `DispatchSourceTimer`:

| Feature | TimelineView | Timer |
|---------|-------------|-------|
| Frame synchronization | Synchronized with display refresh | Arbitrary timing |
| Battery efficiency | Pauses when off-screen | Continues firing |
| Coalescing | Automatic frame coalescing | Manual implementation |
| Thread safety | Runs on main thread | Requires dispatch |

```swift
// CORRECT: TimelineView with animation scheduler
TimelineView(.animation(minimumInterval: 1/60, paused: !isRecording)) { timeline in
    Canvas { context, size in
        drawWaveform(in: &context, size: size, time: timeline.date)
    }
}

// WRONG: Timer-based updates
.onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
    self.currentTime = Date() // Triggers full view re-evaluation
}
```

### Renderer Class Design (Critical)

**ALWAYS use classes (not structs) for renderers:**

```swift
// CORRECT: Class maintains state across frames
@MainActor
final class FluidWaveformRenderer: WaveformRendering {
    private var smoothedLevels: [Double] = []

    func render(context: inout GraphicsContext, size: CGSize, levels: [Double], time: Date) {
        // State persists across calls
        if smoothedLevels.count != levels.count {
            smoothedLevels = levels
        }
        // Smooth in place
        for i in levels.indices {
            smoothedLevels[i] = smoothedLevels[i] * 0.7 + levels[i] * 0.3
        }
    }
}

// WRONG: Struct loses state every frame
struct FluidWaveformRenderer: WaveformRendering {
    private var smoothedLevels: [Double] = []
    // Each call gets a COPY - state is lost!
}
```

### Avoiding View Invalidation During Animation

The golden rule: **Minimize state changes that trigger view body re-evaluation.**

**Strategy 1: Cache renderer in @State**
```swift
struct WaveformContainerView: View {
    @State private var renderer: WaveformRendering?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                renderer?.render(...)  // Renderer persists
            }
        }
        .onAppear {
            if renderer == nil {
                renderer = makeRenderer()  // Create once
            }
        }
    }
}
```

**Strategy 2: Pass data through closure capture**
```swift
Canvas { [audioLevels] context, size in
    // Captured values don't trigger re-renders
    drawBars(context: &context, levels: audioLevels, size: size)
}
```

**Strategy 3: Separate animation concerns**
```swift
struct WaveformView: View {
    var body: some View {
        GeometryReader { geometry in
            // Size determined once
            let _ = print("GeometryReader evaluated once")

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    // Only this closure re-executes at 60fps
                    renderWaveform(context: &context, size: size, time: timeline.date)
                }
            }
        }
    }
}
```

### Memory Management for Continuous Animations

Long-running recordings require careful memory management:

```swift
@MainActor
@Observable
final class AudioLevelBuffer {
    private let maxSamples: Int
    private var samples: CircularBuffer<Double>

    init(duration: TimeInterval, sampleRate: Double) {
        maxSamples = Int(duration * sampleRate)
        samples = CircularBuffer(capacity: maxSamples)
    }

    func append(_ level: Double) {
        samples.append(level) // O(1) operation
    }

    var currentSnapshot: [Double] {
        Array(samples) // Copy for rendering
    }
}
```

**Memory guidelines:**
- Use circular buffers instead of array appending/removing
- Pre-allocate arrays to avoid repeated allocation
- Limit buffer history to visible duration + small padding
- Release audio samples after processing (don't retain raw audio)

## 2. SwiftUI Specific

### Using TimelineView(.animation) Scheduler

The `.animation` scheduler is purpose-built for smooth animations:

```swift
TimelineView(
    .animation(
        minimumInterval: 1/60,  // Cap at 60fps
        paused: !isRecording     // Automatically pause when not needed
    )
) { timeline in
    WaveformCanvas(
        levels: audioLevels,
        currentTime: timeline.date
    )
}
```

**Benefits:**
- Automatically pauses when view is not visible
- Coalesces frames when system is under load
- Synchronizes with Core Animation's render loop

### Canvas Drawing Context Best Practices

**Layer caching for static elements:**
```swift
Canvas { context, size in
    // Cache background grid - doesn't change often
    if let cachedGrid = gridCache {
        context.draw(cachedGrid, at: .zero)
    } else {
        let grid = generateGrid(size: size)
        gridCache = context.resolveSymbol(id: "grid")
        context.draw(grid, at: .zero)
    }

    // Dynamic waveform - drawn every frame
    drawWaveform(in: &context, size: size)
}
.symbols {
    // Define symbols for reuse
    GridLines()
        .tag("grid")
}
```

**Efficient coordinate calculations:**
```swift
private func barRect(at index: Int, level: Double, size: CGSize) -> CGRect {
    let barWidth = (Double(size.width) - spacing * Double(barCount - 1)) / Double(barCount)
    let x = Double(index) * (barWidth + spacing)
    let height = level * Double(size.height)
    let y = (Double(size.height) - height) / 2  // Center vertically

    return CGRect(x: x, y: y, width: barWidth, height: height)
}
```

### Path Creation and Caching Strategies

**Precompute paths when possible:**
```swift
@MainActor
@Observable
final class WaveformPathCache {
    private var barPathCache: [String: Path] = [:]

    func path(for rect: CGRect, cornerRadius: Double) -> Path {
        let key = "\(rect.width)-\(rect.height)-\(cornerRadius)"

        if let cached = barPathCache[key] {
            return cached
        }

        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        barPathCache[key] = path
        return path
    }

    func clearCache() {
        barPathCache.removeAll()
    }
}
```

**For rounded rectangles, use predefined radii:**
```swift
extension Path {
    private static let roundedBarCache = NSCache<NSString, Path>()

    static func roundedBar(width: Double, height: Double, radius: Double) -> Path {
        let key = "\(width)-\(height)-\(radius)" as NSString

        if let cached = roundedBarCache.object(forKey: key) {
            return cached
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: radius)
        roundedBarCache.setObject(path, forKey: key)
        return path
    }
}
```

### Color and Gradient Rendering

**Prefer solid colors for performance:**
```swift
// Fastest - solid color
context.fill(path, with: .color(.blue))

// Good - linear gradient (hardware accelerated)
context.fill(path, with: .linearGradient(
    Gradient(colors: [.blue, .purple]),
    startPoint: .top,
    endPoint: .bottom
))

// Slower - radial/angular gradients
context.fill(path, with: .radialGradient(...))
```

**Use semantic colors for accessibility:**
```swift
// CORRECT: Adapts to light/dark mode
context.fill(path, with: .color(Color.primary.opacity(0.8)))

// WRONG: Hardcoded color doesn't adapt
context.fill(path, with: .color(.white.opacity(0.8)))
```

**Reuse gradients:**
```swift
struct WaveformStyle {
    static let activeGradient = Gradient(colors: [
        Color(red: 0.2, green: 0.6, blue: 1.0),
        Color(red: 0.4, green: 0.2, blue: 0.9)
    ])

    static let inactiveGradient = Gradient(colors: [
        Color.gray.opacity(0.3),
        Color.gray.opacity(0.1)
    ])
}
```

## 3. Audio Processing

### Working with AudioLevelProviding Protocol

Define a clean protocol for audio level providers:

```swift
// Domain/Protocols/AudioLevelProviding.swift
protocol AudioLevelProviding: Sendable {
    /// Current audio levels (normalized 0.0...1.0)
    var levels: [Double] { get }

    /// Start monitoring audio levels
    func start()

    /// Stop monitoring audio levels
    func stop()
}
```

**Implementation in Infrastructure layer:**
```swift
// Infrastructure/Audio/AudioLevelMonitor.swift
import AVFoundation

@MainActor
final class AudioLevelMonitor: AudioLevelProviding {
    private(set) var levels: [Double] = Array(repeating: 0.1, count: 20)
    private var audioEngine: AVAudioEngine?
    private var isMonitoring = false

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        // Setup AVAudioEngine tap...
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        audioEngine?.stop()
        audioEngine = nil
    }
}
```

### Throttling Audio Level Updates

Audio engines may provide updates at much higher rates than needed for visualization:

```swift
/// Throttled wrapper that limits update frequency
/// NOTE: This wraps rather than conforms to AudioLevelProviding to avoid protocol mismatch
actor ThrottledAudioProvider {
    private let source: AudioLevelProviding
    private let updateInterval: TimeInterval
    private var lastUpdate: Date = .distantPast
    private(set) var throttledLevels: [Double] = []

    init(source: AudioLevelProviding, updateInterval: TimeInterval = 1.0/60.0) {
        self.source = source
        self.updateInterval = updateInterval
    }

    func startMonitoring() async throws {
        source.start()

        // Throttle to 60fps using Task.sleep (Sendable-compliant)
        while true {
            // Access levels synchronously through the provider's property
            let currentLevels = source.levels
            await updateIfNeeded(levels: currentLevels)
            try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
        }
    }

    @MainActor
    private func updateIfNeeded(levels: [Double]) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdate) >= updateInterval else { return }
        lastUpdate = now
        throttledLevels = levels
        // Notify view model via Observable or continuation...
    }
}
```

**Why Task.sleep instead of Timer:**
- `Task.sleep` is `Sendable`-compliant (works with Swift concurrency)
- `Timer` is not `Sendable` and causes actor isolation issues
- `Task.sleep` integrates better with cancellation

### Smoothing Algorithms for Waveform

Raw audio levels are too jittery for pleasant visualization. Apply smoothing:

**Exponential Moving Average (EMA):**
```swift
struct SmoothedAudioLevel {
    private var smoothedValue: Double = 0
    private let alpha: Double  // Smoothing factor (0...1)

    mutating func update(with newValue: Double) -> Double {
        smoothedValue = alpha * newValue + (1 - alpha) * smoothedValue
        return smoothedValue
    }
}
```

**Attack/Release envelope (more natural):**
```swift
struct EnvelopeFollower {
    private var envelope: Double = 0
    private let attackCoefficient: Double   // Fast response to increase
    private let releaseCoefficient: Double  // Slow decay

    mutating func process(_ input: Double) -> Double {
        let absInput = abs(input)

        if absInput > envelope {
            envelope = attackCoefficient * (envelope - absInput) + absInput
        } else {
            envelope = releaseCoefficient * (envelope - absInput) + absInput
        }

        return envelope
    }
}
```

## 4. Code Quality

### Protocol-Oriented Design for Renderers

Separate rendering logic from data:

```swift
// MARK: - Protocols (Presentation Layer)

protocol WaveformRendering: AnyObject {
    func render(
        context: inout GraphicsContext,
        size: CGSize,
        levels: [Double],
        time: Date
    )
}

protocol WaveformStyling {
    var barColor: Color { get }
    var barSpacing: Double { get }
    var barCornerRadius: Double { get }
}

// MARK: - Implementations

@MainActor
final class BarWaveformRenderer: WaveformRendering {
    let style: WaveformStyling

    init(style: WaveformStyling) {
        self.style = style
    }

    func render(context: inout GraphicsContext, size: CGSize, levels: [Double], time: Date) {
        // Implementation...
    }
}
```

### Testability with Mock Data

Create mock providers for testing:

```swift
@MainActor
final class MockAudioProvider: AudioLevelProviding {
    private(set) var levels: [Double] = []
    private var task: Task<Void, Never>?

    func simulateRecording(pattern: WaveformPattern) {
        task = Task {
            for level in pattern.levels {
                levels.append(level)
                if levels.count > 60 {
                    levels.removeFirst()
                }
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
            }
        }
    }

    func start() {}
    func stop() {
        task?.cancel()
    }
}

enum WaveformPattern {
    case silence(duration: TimeInterval)
    case sineWave(frequency: Double, amplitude: Double)
    case randomNoise(seed: Int)
    case recordedSamples([Double])

    var levels: [Double] {
        // Generate appropriate samples...
        []
    }
}
```

### Preview Support

Make previews useful with mock data:

```swift
#Preview("Static Waveform") {
    WaveformView(
        levels: [0.2, 0.5, 0.8, 0.3, 0.9, 0.4, 0.6, 0.7],
        style: .default
    )
    .frame(width: 300, height: 60)
}

#Preview("Animated Waveform") {
    struct AnimatedPreview: View {
        @State private var levels: [Double] = []

        var body: some View {
            WaveformView(levels: levels, style: .default)
                .frame(width: 400, height: 80)
                .task {
                    // Use Task.sleep instead of Timer
                    while !Task.isCancelled {
                        levels.append(Double.random(in: 0.1...0.9))
                        if levels.count > 50 {
                            levels.removeFirst()
                        }
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                }
        }
    }

    return AnimatedPreview()
}
```

## 5. macOS Specific

### AppKit vs SwiftUI Considerations

While SwiftUI Canvas is preferred, be aware of AppKit alternatives:

| Scenario | Recommendation |
|----------|---------------|
| Simple waveform | SwiftUI Canvas |
| Complex waveform editing | AppKit with CALayer |
| Need Metal shaders | MTKView wrapper |
| Accessibility requirements | SwiftUI with fallback |

### Window Management with Waveform

For overlay-style windows (like the capsule window):

```swift
struct WaveformOverlayWindow: Scene {
    var body: some Scene {
        WindowGroup("Waveform") {
            WaveformView(...)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
```

### Energy Efficiency for Background Operation

Reduce power consumption when not actively recording:

```swift
@MainActor
@Observable
final class WaveformViewModel {
    var isRecording = false

    // Use TimelineView's paused parameter instead of didSet
    var timelinePaused: Bool { !isRecording }

    func updateDisplayLink() {
        // TimelineView handles pausing automatically
        // Just update the paused binding
    }
}
```

**Energy-saving tips:**
- Pause TimelineView when window is occluded
- Reduce frame rate when window is in background
- Stop audio processing when app is hidden (if appropriate)
- Use `NSScreen.screensHaveSeparateSpaces` to detect multi-monitor setups

## 6. Security Considerations

### Audio Data Handling

**Never log raw audio data:**
```swift
// WRONG - Could leak sensitive audio content
logger.debug("Audio buffer: \(audioBuffer)")

// CORRECT - Only log metadata
logger.debug("Audio buffer received: \(audioBuffer.frameLength) frames at \(audioBuffer.format.sampleRate)Hz")
```

**Secure audio session configuration:**
```swift
let audioSession = AVAudioSession.sharedInstance()
do {
    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
    try audioSession.setActive(true)
} catch {
    logger.error("Failed to configure audio session: \(error.localizedDescription)")
    // Don't expose internal error details to user
}
```

### No Sensitive Data in Logs

Sanitize all logging:
```swift
extension AudioLevelProvider {
    private func logLevelChange(_ level: Double) {
        // Log only statistical information
        logger.debug("Audio level updated", metadata: [
            "range": .string(level > 0.5 ? "high" : level > 0.2 ? "medium" : "low"),
            "timestamp": .string(Date().iso8601)
        ])
    }
}
```

## 7. Common Pitfalls

### Pitfall 1: Using CGFloat in Domain Layer

**WRONG:**
```swift
// Domain/Entities/WaveformData.swift
struct WaveformData {
    let levels: [CGFloat]  // ❌ CoreGraphics type in Domain
}
```

**CORRECT:**
```swift
// Domain/Entities/WaveformData.swift
struct WaveformData {
    let levels: [Double]  // ✅ Standard library type
}

// Presentation layer conversion
let cgLevels = domainData.levels.map(CGFloat.init)
```

### Pitfall 2: Mixing @Observable with didSet

**WRONG:**
```swift
@MainActor
@Observable
final class Settings {
    var style: WaveformStyle = .fluid {
        didSet {  // ❌ @Observable doesn't work well with didSet
            UserDefaults.standard.set(style.rawValue, forKey: "style")
        }
    }
}
```

**CORRECT:**
```swift
@MainActor
@Observable
final class Settings {
    var style: WaveformStyle {
        get {
            let saved = UserDefaults.standard.string(forKey: "style") ?? ""
            return WaveformStyle(rawValue: saved) ?? .fluid
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "style")
        }
    }
}
```

### Pitfall 3: Creating Renderer in Body

**WRONG:**
```swift
var body: some View {
    TimelineView(.animation) { timeline in
        Canvas { context, size in
            let renderer = style.makeRenderer()  // ❌ New instance every frame!
            renderer?.render(...)
        }
    }
}
```

**CORRECT:**
```swift
struct WaveformView: View {
    @State private var renderer: WaveformRendering?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                renderer?.render(...)  // ✅ Reuse cached instance
            }
        }
        .onAppear {
            if renderer == nil {
                renderer = style.makeRenderer()  // ✅ Create once
            }
        }
    }
}
```

## References

- [WaveformScrubber](https://github.com/johnsonaj/WaveformScrubber) - Excellent protocol-based design example
- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [TimelineView Animation Scheduler](https://developer.apple.com/documentation/swiftui/timelineview/animation(minimuminterval:paused:))
- [Accelerate Framework vDSP](https://developer.apple.com/documentation/accelerate/vdsp) - For advanced audio processing
