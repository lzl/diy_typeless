import SwiftUI

struct CapsuleView: View {
    @ObservedObject var state: RecordingState
    @StateObject private var audioMonitor = AudioLevelMonitor()
    @State private var progress: CGFloat = 0

    private let capsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36

    var body: some View {
        ZStack {
            // Background with progress
            Capsule(style: .continuous)
                .fill(Color(white: 0.12))

            // Progress overlay for transcribing/polishing
            if case .transcribing = state.capsuleState {
                progressOverlay
            } else if case .polishing = state.capsuleState {
                progressOverlay
            }

            // Content
            content
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .onChange(of: state.capsuleState) { newState in
            handleStateChange(newState)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.capsuleState {
        case .recording:
            WaveformView(levels: audioMonitor.levels)
                .frame(width: capsuleWidth - 32)

        case .transcribing:
            Text("Transcribing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

        case .streaming(let partialText):
            // Show partial text with typing indicator
            HStack(spacing: 4) {
                Text(partialText.isEmpty ? "Listening..." : partialText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Blinking cursor indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .opacity(0.8)
            }

        case .polishing:
            Text("Polishing")
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

        case .transcribing, .streaming:
            // Both transcribing and streaming show progress
            audioMonitor.stop()
            startProgressAnimation(duration: 2.5)

        case .polishing:
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
