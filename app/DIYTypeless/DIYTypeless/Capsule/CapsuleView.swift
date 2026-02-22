import SwiftUI

struct CapsuleView: View {
    @Bindable var state: RecordingState
    @State private var audioMonitor = AudioLevelMonitor()
    @State private var progress: CGFloat = 0
    @State private var showGlow: Bool = false
    @State private var shakeTrigger: Bool = false
    @State private var showSuccessPulse: Bool = false

    private let capsuleWidth: CGFloat = 160
    private let capsuleHeight: CGFloat = 36

    var body: some View {
        ZStack {
            // Background with state-based coloring
            stateBackground

            // Progress overlay for transcribing/polishing
            if case .transcribing = state.capsuleState {
                progressOverlay
            } else if case .polishing = state.capsuleState {
                progressOverlay
            }

            // Success pulse effect
            if showSuccessPulse {
                successPulseOverlay
            }

            // Content
            content
        }
        .frame(width: capsuleWidth, height: capsuleHeight)
        .onChange(of: state.capsuleState) { oldState, newState in
            handleStateChange(oldState: oldState, newState: newState)
        }
    }

    @ViewBuilder
    private var stateBackground: some View {
        Group {
            switch state.capsuleState {
            case .recording:
                Capsule(style: .continuous)
                    .fill(Color.recordingBackground)
            case .transcribing:
                Capsule(style: .continuous)
                    .fill(Color.transcribingBackground)
            case .polishing:
                Capsule(style: .continuous)
                    .fill(Color.polishingBackground)
            case .done:
                Capsule(style: .continuous)
                    .fill(Color.completedBackground)
            case .error:
                Capsule(style: .continuous)
                    .fill(Color.error.opacity(0.2))
            default:
                Capsule(style: .continuous)
                    .fill(Color(white: 0.12))
            }
        }
        .animation(AppAnimation.stateChange, value: state.capsuleState)
    }

    @ViewBuilder
    private var successPulseOverlay: some View {
        Capsule(style: .continuous)
            .stroke(Color.success.opacity(0.5), lineWidth: 2)
            .scaleEffect(showSuccessPulse ? 1.1 : 1.0)
            .opacity(showSuccessPulse ? 0 : 1)
            .animation(.easeOut(duration: 0.4), value: showSuccessPulse)
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 8) {
            // Status icon with morphing animation
            statusIcon
                .frame(width: 16, height: 16)

            // Text with crossfade transition
            statusText
        }
        .padding(.horizontal, 12)
        .shake(trigger: shakeTrigger, intensity: 5)
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            switch state.capsuleState {
            case .recording:
                RecordingIndicator()
            case .transcribing:
                WaveIcon()
            case .polishing:
                SparkleIcon()
            case .done:
                CheckmarkIcon()
            case .error:
                ErrorIcon()
            default:
                EmptyView()
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(AppAnimation.stateChange, value: state.capsuleState)
    }

    @ViewBuilder
    private var statusText: some View {
        Group {
            switch state.capsuleState {
            case .recording:
                WaveformView(audioProvider: audioMonitor)
                    .frame(width: capsuleWidth - 60)

            case .transcribing:
                Text("Transcribing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .contentTransition(.opacity)

            case .polishing:
                Text("Polishing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .contentTransition(.opacity)

            case .done(let result):
                Text(result == .pasted ? "Pasted" : "Copied")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .contentTransition(.opacity)

            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.warning)
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.warning)
                        .lineLimit(1)
                }

            case .hidden:
                EmptyView()
            }
        }
        .animation(AppAnimation.stateChange, value: state.capsuleState)
    }

    private var progressOverlay: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: geo.size.width * progress)

                // Trailing glow effect
                if progress > 0 && progress < 1 {
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20, height: capsuleHeight)
                        .offset(x: geo.size.width * progress - 10)
                        .opacity(showGlow ? 1.0 : 0.3)
                        .animation(AppAnimation.pulse(duration: 0.8), value: showGlow)
                    }
                }
            }
        }
        .clipShape(Capsule(style: .continuous))
        .animation(AppAnimation.progressFill, value: progress)
    }

    private func handleStateChange(oldState: CapsuleState, newState: CapsuleState) {
        switch newState {
        case .recording:
            audioMonitor.start()
            progress = 0
            showGlow = false
            showSuccessPulse = false

        case .transcribing:
            audioMonitor.stop()
            startProgressAnimation(duration: 2.5)
            showGlow = true
            showSuccessPulse = false

        case .polishing:
            startProgressAnimation(duration: 2.0)
            showGlow = true
            showSuccessPulse = false

        case .done:
            audioMonitor.stop()
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 1.0
            }
            showGlow = false
            // Trigger success pulse animation
            showSuccessPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showSuccessPulse = false
            }

        case .error:
            audioMonitor.stop()
            showGlow = false
            showSuccessPulse = false
            // Trigger shake animation
            shakeTrigger.toggle()

        case .hidden:
            audioMonitor.stop()
            progress = 0
            showGlow = false
            showSuccessPulse = false
        }
    }

    private func startProgressAnimation(duration: Double) {
        progress = 0
        withAnimation(.easeInOut(duration: duration)) {
            progress = 0.85
        }
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.error)
            .frame(width: 8, height: 8)
            .shadow(
                color: Color.error.opacity(0.5 + (isPulsing ? 0.3 : 0)),
                radius: isPulsing ? 8 : 4,
                x: 0,
                y: 0
            )
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(AppAnimation.pulse(duration: 1.0), value: isPulsing)
            .onAppear { isPulsing = true }
            .onDisappear { isPulsing = false }
    }
}

// MARK: - Wave Icon

struct WaveIcon: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.brandPrimaryLight)
                    .frame(width: 2, height: waveHeight(for: index))
                    .animation(
                        AppAnimation.waveformBar.delay(Double(index) * 0.1),
                        value: phase
                    )
            }
        }
        .onAppear {
            withAnimation(AppAnimation.breathing(duration: 0.6)) {
                phase = 1
            }
        }
    }

    private func waveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let variation: CGFloat = 4
        let offset = CGFloat(index) * 0.3
        return baseHeight + variation * sin((phase + offset) * .pi * 2)
    }
}

// MARK: - Sparkle Icon

struct SparkleIcon: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.brandAccentLight)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .animation(AppAnimation.breathing(duration: 0.8), value: scale)
            .onAppear {
                rotation = 15
                scale = 1.1
            }
    }
}

// MARK: - Checkmark Icon

struct CheckmarkIcon: View {
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        Circle()
            .stroke(Color.success, lineWidth: 1.5)
            .frame(width: 14, height: 14)
            .overlay(
                CheckmarkShape()
                    .trim(from: 0, to: drawProgress)
                    .stroke(Color.success, lineWidth: 1.5)
                    .frame(width: 8, height: 6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    drawProgress = 1.0
                }
            }
    }
}

// MARK: - Error Icon

struct ErrorIcon: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.warning)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Checkmark Shape

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.2, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.75))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.25))

        return path
    }
}

// MARK: - Shake View Extension

private struct ShakeModifier: ViewModifier {
    let trigger: Bool
    let intensity: CGFloat
    @State private var shakeCount: Int = 0

    func body(content: Content) -> some View {
        content
            .offset(x: calculateOffset())
            .onChange(of: trigger) { _, _ in
                performShake()
            }
    }

    private func calculateOffset() -> CGFloat {
        guard shakeCount > 0 else { return 0 }
        // Shake pattern: 0, +intensity, -intensity, +intensity, -intensity, 0
        let phase = shakeCount % 6
        switch phase {
        case 1, 3: return intensity
        case 2, 4: return -intensity
        default: return 0
        }
    }

    private func performShake() {
        shakeCount = 0
        for i in 1..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) {
                withAnimation(AppAnimation.shake) {
                    shakeCount = i
                }
            }
        }
    }
}

extension View {
    fileprivate func shake(trigger: Bool, intensity: CGFloat = 5) -> some View {
        modifier(ShakeModifier(trigger: trigger, intensity: intensity))
    }
}
