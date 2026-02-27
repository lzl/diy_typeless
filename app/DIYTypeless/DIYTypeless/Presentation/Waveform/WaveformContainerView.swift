import SwiftUI

/// Container view for waveform visualization using TimelineView + Canvas
/// Provides 60fps GPU-accelerated rendering with stateful renderer caching
struct WaveformContainerView: View {
    private let audioMonitor: any AudioLevelProviding
    private let style: WaveformStyle

    @State private var renderer: WaveformRendering?
    @State private var levels: [Double] = Array(repeating: 0.0, count: 20)  // Initial flat line

    init(
        audioMonitor: some AudioLevelProviding,
        style: WaveformStyle = .fluid
    ) {
        self.audioMonitor = audioMonitor
        self.style = style
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { context, size in
                // Ensure renderer exists
                let r = renderer ?? WaveformRendererFactory.makeRenderer(for: style)
                if renderer == nil {
                    renderer = r
                }
                r?.render(
                    context: context,
                    size: size,
                    levels: levels,
                    time: timeline.date
                )
            }
        }
        .onAppear {
            // Initialize renderer on main thread
            if renderer == nil {
                renderer = WaveformRendererFactory.makeRenderer(for: style)
            }
        }
        .onChange(of: style) { _, newStyle in
            // Recreate renderer when style changes
            renderer = WaveformRendererFactory.makeRenderer(for: newStyle)
        }
        .task {
            // Subscribe to audio level updates via AsyncStream
            await subscribeToAudioLevels()
        }
    }

    private func subscribeToAudioLevels() async {
        let stream = await audioMonitor.levelsStream
        for await newLevels in stream {
            await MainActor.run {
                levels = newLevels
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
// Simple mock for previews only
@MainActor
private final class PreviewAudioMonitor: AudioLevelProviding, @unchecked Sendable {
    let levels: [Double] = []
    nonisolated var levelsStream: AsyncStream<[Double]> {
        AsyncStream { continuation in
            // Simulate animated levels
            Task {
                var time: Double = 0
                while !Task.isCancelled {
                    var simulatedLevels: [Double] = []
                    for i in 0..<20 {
                        let phase = time + Double(i) * 0.3
                        let level = (sin(phase) + 1) * 0.3 + 0.05
                        simulatedLevels.append(min(level, 1.0))
                    }
                    continuation.yield(simulatedLevels)
                    time += 0.1
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }
    }
}

#Preview {
    WaveformContainerView(
        audioMonitor: PreviewAudioMonitor(),
        style: .fluid
    )
    .frame(width: 200, height: 40)
}
#endif
