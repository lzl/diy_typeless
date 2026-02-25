import SwiftUI

struct CapsuleView: View {
    let state: RecordingState
    private let audioMonitor: AudioLevelProviding
    @State private var progress: CGFloat = 0

    /// Creates a capsule view with a recording state and optional audio level provider
    /// - Parameters:
    ///   - state: The recording state to display
    ///   - audioMonitor: Provider for audio level data (defaults to AudioLevelMonitor)
    init(state: RecordingState, audioMonitor: AudioLevelProviding = AudioLevelMonitor()) {
        self.state = state
        self.audioMonitor = audioMonitor
    }

    private let capsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36

    private var shouldShowProgress: Bool {
        switch state.capsuleState {
        case .transcribing, .polishing, .processingCommand:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            // Subtle gradient background for depth
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.18),
                            Color(white: 0.12),
                            Color(white: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Subtle top edge highlight
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                .padding(0.5)

            // Progress overlay for processing states
            if shouldShowProgress {
                progressOverlay
            }

            // Content
            content
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .onChange(of: state.capsuleState) { _, newState in
            handleStateChange(newState)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.capsuleState {
        case .recording:
            WaveformView(audioProvider: audioMonitor)
                .frame(width: capsuleWidth - 32)

        case .transcribing:
            Text("Transcribing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .polishing:
            Text("Polishing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .processingCommand:
            Text("Processing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .done(let result):
            Text(result == .pasted ? "Pasted" : "Copied")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(1)

        case .hidden:
            EmptyView()
        }
    }

    private var progressOverlay: some View {
        GeometryReader { geo in
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: geo.size.width * progress)
        }
        .clipShape(Capsule(style: .continuous))
    }

    private func handleStateChange(_ newState: CapsuleState) {
        switch newState {
        case .recording:
            audioMonitor.start()
            progress = 0

        case .transcribing:
            audioMonitor.stop()
            startProgressAnimation(duration: 2.5)

        case .polishing, .processingCommand:
            startProgressAnimation(duration: 2.0)

        case .done, .error:
            audioMonitor.stop()
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 1.0
            }

        case .hidden:
            audioMonitor.stop()
            progress = 0
        }
    }

    private func startProgressAnimation(duration: Double) {
        progress = 0
        withAnimation(.easeInOut(duration: duration)) {
            progress = 0.85
        }
    }
}
