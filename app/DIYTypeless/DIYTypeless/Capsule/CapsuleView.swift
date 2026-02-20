import SwiftUI

struct CapsuleView: View {
    @ObservedObject var state: RecordingState
    @StateObject private var audioMonitor = AudioLevelMonitor()
    @State private var progress: CGFloat = 0

    private let capsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36

    // Check if this is dev build based on bundle identifier
    private var isDevBuild: Bool {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let isDev = bundleId.contains(".dev")
        print("[CapsuleView] Bundle ID: \(bundleId), isDevBuild: \(isDev)")
        return isDev
    }

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
        // Dev build only: Show live transcription above capsule
        .overlay(alignment: .bottom) {
            if isDevBuild && shouldShowLiveTranscription {
                liveTranscriptionOverlay
                    .padding(.bottom, capsuleHeight + 8)
            }
        }
    }

    // Only show live transcription during recording/transcribing/polishing
    private var shouldShowLiveTranscription: Bool {
        switch state.capsuleState {
        case .recording, .transcribing, .polishing, .streaming:
            return !state.liveTranscriptionText.isEmpty
        default:
            return false
        }
    }

    // Dev build: Display live transcription text (full text, no truncation)
    private var liveTranscriptionOverlay: some View {
        Text(state.liveTranscriptionText)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .frame(maxWidth: 600)
            .fixedSize(horizontal: false, vertical: true)
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

        case .streaming:
            // Should not happen with unified UI, but show transcribing as fallback
            Text("Transcribing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

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

        case .transcribing:
            audioMonitor.stop()
            startProgressAnimation(duration: 2.5)

        case .streaming:
            // Not used with unified UI
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
