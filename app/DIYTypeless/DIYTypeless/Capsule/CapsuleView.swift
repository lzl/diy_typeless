import SwiftUI

struct CapsuleView: View {
    let state: RecordingState
    private let audioMonitor: any AudioLevelProviding
    @State private var progress: CGFloat = 0
    @State private var previousState: CapsuleState?

    /// Creates a capsule view with a recording state and optional audio level monitor
    /// - Parameters:
    ///   - state: The recording state to display
    ///   - audioMonitor: Monitor for audio level data (defaults to AudioLevelMonitor)
    init(state: RecordingState, audioMonitor: any AudioLevelProviding = AudioLevelMonitor()) {
        self.state = state
        self.audioMonitor = audioMonitor
    }

    private let minCapsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36
    private let contentPadding: CGFloat = 20

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
        .frame(minWidth: minCapsuleWidth)
        .frame(height: capsuleHeight)
        .onAppear {
            // Handle initial state
            previousState = state.capsuleState
            handleStateChange(state.capsuleState)
        }
        .onChange(of: state.capsuleState) { _, newState in
            // Only handle if state actually changed
            guard previousState != newState else { return }
            previousState = newState
            handleStateChange(newState)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.capsuleState {
        case .recording:
            WaveformContainerView(
                audioMonitor: audioMonitor,
                style: .bars
            )
            .frame(width: minCapsuleWidth - 32, height: 32)
            .transition(.opacity.animation(.easeOut(duration: 0.2)))
            .accessibilityLabel("Recording audio")

        case .transcribing:
            Text("Transcribing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, contentPadding)

        case .polishing:
            Text("Polishing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, contentPadding)

        case .processingCommand:
            Text("Processing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, contentPadding)

        case .done(let result):
            Text(result == .pasted ? "Pasted" : "Copied")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, contentPadding)

        case .error(let error):
            Text(error.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(errorColor(for: error))
                .lineLimit(1)
                .padding(.horizontal, contentPadding)

        case .hidden:
            EmptyView()
        }
    }

    /// Returns the display color for a UserFacingError based on its severity.
    /// Warning errors (user-fixable) use orange, critical errors use red.
    private func errorColor(for error: UserFacingError) -> Color {
        switch error.severity {
        case .warning:
            return .orange
        case .critical:
            return .red.opacity(0.85)
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
            Task {
                try? audioMonitor.startMonitoring()
            }
            progress = 0

        case .transcribing:
            Task {
                await audioMonitor.stopMonitoring()
            }
            startProgressAnimation(duration: 2.5)

        case .polishing, .processingCommand:
            startProgressAnimation(duration: 2.0)

        case .done, .error:
            Task {
                await audioMonitor.stopMonitoring()
            }
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 1.0
            }

        case .hidden:
            Task {
                await audioMonitor.stopMonitoring()
            }
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
