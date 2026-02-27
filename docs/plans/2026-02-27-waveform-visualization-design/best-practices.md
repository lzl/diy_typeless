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

### Avoiding View Invalidation During Animation

The golden rule: **Minimize state changes that trigger view body re-evaluation.**

**Strategy 1: Use @StateObject for mutable state**
```swift
@MainActor
@Observable
final class WaveformState {
    private(set) var audioLevels: [Float] = []

    func updateLevel(_ level: Float) {
        audioLevels.append(level)
        if audioLevels.count > maxBars {
            audioLevels.removeFirst()
        }
    }
}
```

**Strategy 2: Pass data through Canvas closure capture**
```swift
Canvas { [audioLevels] context, size in
    // Captured values don't trigger re-renders
    drawBars(context: &context, levels: audioLevels, size: size)
}
```

**Strategy 3: Separate animation concerns**
```swift
struct WaveformView: View {
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
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
    private var samples: CircularBuffer<Float>

    init(duration: TimeInterval, sampleRate: Double) {
        maxSamples = Int(duration * sampleRate)
        samples = CircularBuffer(capacity: maxSamples)
    }

    func append(_ level: Float) {
        samples.append(level) // O(1) operation
    }

    var currentSnapshot: [Float] {
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
private func barRect(at index: Int, level: Float, size: CGSize) -> CGRect {
    let barWidth = (size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
    let x = CGFloat(index) * (barWidth + spacing)
    let height = CGFloat(level) * size.height
    let y = (size.height - height) / 2  // Center vertically

    return CGRect(x: x, y: y, width: barWidth, height: height)
}
```

### Path Creation and Caching Strategies

**Precompute paths when possible:**
```swift
@MainActor
@Observable
final class WaveformRenderer {
    private var barPathCache: [CGRect: Path] = [:]

    func path(for rect: CGRect) -> Path {
        if let cached = barPathCache[rect] {
            return cached
        }

        let path = Path(rect)
        barPathCache[rect] = path
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
    static let roundedBarCache = NSCache<NSValue, Path>()

    static func roundedBar(width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        let key = NSValue(cgSize: CGSize(width: width, height: height))

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
protocol AudioLevelProviding: Sendable {
    /// Current audio level in dB (typically -60...0)
    var currentLevel: Float { get }

    /// Subscribe to level updates
    func startMonitoring() async throws
    func stopMonitoring()
}

actor AudioLevelProvider: AudioLevelProviding {
    private var audioEngine: AVAudioEngine?
    private var timer: Timer?
    private(set) var currentLevel: Float = -60.0

    func startMonitoring() async throws {
        // Setup audio tap...
    }

    func stopMonitoring() {
        // Cleanup...
    }
}
```

### Throttling Audio Level Updates

Audio engines may provide updates at much higher rates than needed for visualization:

```swift
actor ThrottledAudioProvider: AudioLevelProviding {
    private let source: AudioLevelProviding
    private let updateInterval: TimeInterval
    private var lastUpdate: Date = .distantPast

    var currentLevel: Float {
        get async {
            await source.currentLevel
        }
    }

    func startMonitoring() async throws {
        try await source.startMonitoring()

        // Throttle to 30fps for UI updates
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task {
                await self.updateLevel()
            }
        }
    }

    private func updateLevel() async {
        let level = await source.currentLevel
        // Notify view model...
    }
}
```

### Smoothing Algorithms for Waveform

Raw audio levels are too jittery for pleasant visualization. Apply smoothing:

**Exponential Moving Average (EMA):**
```swift
struct SmoothedAudioLevel {
    private var smoothedValue: Float = 0
    private let alpha: Float  // Smoothing factor (0...1)

    mutating func update(with newValue: Float) -> Float {
        smoothedValue = alpha * newValue + (1 - alpha) * smoothedValue
        return smoothedValue
    }
}
```

**Attack/Release envelope (more natural):**
```swift
struct EnvelopeFollower {
    private var envelope: Float = 0
    private let attackCoefficient: Float   // Fast response to increase
    private let releaseCoefficient: Float  // Slow decay

    mutating func process(_ input: Float) -> Float {
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
// MARK: - Protocols

protocol WaveformRendering {
    func render(levels: [Float], in context: inout GraphicsContext, size: CGSize)
}

protocol WaveformStyling {
    var barColor: Color { get }
    var barSpacing: CGFloat { get }
    var barCornerRadius: CGFloat { get }
}

// MARK: - Implementations

struct BarWaveformRenderer: WaveformRendering {
    let style: WaveformStyling

    func render(levels: [Float], in context: inout GraphicsContext, size: CGSize) {
        let barWidth = calculateBarWidth(count: levels.count, spacing: style.barSpacing, totalWidth: size.width)

        for (index, level) in levels.enumerated() {
            let rect = barRect(at: index, level: level, barWidth: barWidth, size: size)
            let path = Path(roundedRect: rect, cornerRadius: style.barCornerRadius)
            context.fill(path, with: .color(style.barColor))
        }
    }
}

struct GradientBarWaveformRenderer: WaveformRendering {
    let style: WaveformStyling
    let gradient: Gradient

    func render(levels: [Float], in context: inout GraphicsContext, size: CGSize) {
        // Implementation with gradient fill...
    }
}
```

### Testability with Mock Data

Create mock providers for testing:

```swift
actor MockAudioProvider: AudioLevelProviding {
    private(set) var currentLevel: Float = -60.0
    private var timer: Timer?

    func simulateRecording(pattern: WaveformPattern) async {
        for level in pattern.levels {
            currentLevel = level
            try? await Task.sleep(nanoseconds: 33_333_333) // ~30fps
        }
    }
}

enum WaveformPattern {
    case silence(duration: TimeInterval)
    case sineWave(frequency: Double, amplitude: Float)
    case randomNoise(seed: Int)
    case recordedSamples([Float])

    var levels: [Float] {
        // Generate appropriate samples...
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
        @State private var levels: [Float] = []
        private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

        var body: some View {
            WaveformView(levels: levels, style: .default)
                .frame(width: 400, height: 80)
                .onReceive(timer) { _ in
                    levels.append(Float.random(in: 0.1...0.9))
                    if levels.count > 50 {
                        levels.removeFirst()
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

**Hybrid approach for complex cases:**
```swift
struct WaveformNSViewRepresentable: NSViewRepresentable {
    var levels: [Float]

    func makeNSView(context: Context) -> WaveformView {
        WaveformView()
    }

    func updateNSView(_ nsView: WaveformView, context: Context) {
        nsView.levels = levels
    }
}

class WaveformView: NSView {
    var levels: [Float] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Custom drawing with Core Graphics...
    }
}
```

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
    var isRecording = false {
        didSet {
            updateDisplayLink()
        }
    }

    private func updateDisplayLink() {
        if isRecording {
            // Full 60fps animation
            displayLink.preferredFramesPerSecond = 60
        } else {
            // Pause animation entirely
            displayLink.isPaused = true
        }
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
    private func logLevelChange(_ level: Float) {
        // Log only statistical information
        logger.debug("Audio level updated", metadata: [
            "range": .string(level > -20 ? "high" : level > -40 ? "medium" : "low"),
            "timestamp": .string(Date().iso8601)
        ])
    }
}
```

## References

- [WaveformScrubber](https://github.com/johnsonaj/WaveformScrubber) - Excellent protocol-based design example
- [SwiftUI Canvas Documentation](https://developer.apple.com/documentation/swiftui/canvas)
- [TimelineView Animation Scheduler](https://developer.apple.com/documentation/swiftui/timelineview/animation(minimuminterval:paused:))
- [Accelerate Framework vDSP](https://developer.apple.com/documentation/accelerate/vdsp) - For advanced audio processing
