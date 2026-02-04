import Combine
import SwiftUI

struct CapsuleView: View {
    @ObservedObject var state: RecordingState

    var body: some View {
        let presentation = presentation(for: state.capsuleState)

        HStack(spacing: 12) {
            Image(systemName: presentation.icon)
                .foregroundColor(presentation.color)
                .font(.system(size: 18, weight: .semibold))

            Text(presentation.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if presentation.showsWaveform {
                WaveformView()
                    .frame(height: 20)
            }

            if presentation.showsDots {
                LoadingDotsView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .frame(maxWidth: 380)
    }

    private func presentation(for state: CapsuleState) -> CapsulePresentation {
        switch state {
        case .recording:
            return CapsulePresentation(
                icon: "mic.fill",
                text: "Recording",
                color: .red,
                showsWaveform: true,
                showsDots: false
            )
        case .transcribing:
            return CapsulePresentation(
                icon: "text.bubble",
                text: "Transcribing",
                color: .blue,
                showsWaveform: false,
                showsDots: true
            )
        case .polishing:
            return CapsulePresentation(
                icon: "sparkles",
                text: "Polishing",
                color: .purple,
                showsWaveform: false,
                showsDots: true
            )
        case .done(let result):
            switch result {
            case .pasted:
                return CapsulePresentation(
                    icon: "checkmark.circle.fill",
                    text: "Pasted",
                    color: .green,
                    showsWaveform: false,
                    showsDots: false
                )
            case .copied:
                return CapsulePresentation(
                    icon: "doc.on.clipboard",
                    text: "Copied",
                    color: .green,
                    showsWaveform: false,
                    showsDots: false
                )
            }
        case .error(let message):
            return CapsulePresentation(
                icon: "exclamationmark.triangle.fill",
                text: "Error: \(message)",
                color: .orange,
                showsWaveform: false,
                showsDots: false
            )
        case .hidden:
            return CapsulePresentation(
                icon: "mic.fill",
                text: "",
                color: .clear,
                showsWaveform: false,
                showsDots: false
            )
        }
    }
}

private struct CapsulePresentation {
    let icon: String
    let text: String
    let color: Color
    let showsWaveform: Bool
    let showsDots: Bool
}

private struct LoadingDotsView: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.primary.opacity(index == phase ? 0.9 : 0.3))
                    .frame(width: 4, height: 4)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
