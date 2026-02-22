import SwiftUI

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing background rings
                if !state.permissions.microphone {
                    pulsingRings
                }
                
                PermissionIcon(
                    icon: "mic.fill",
                    granted: state.permissions.microphone
                )
                .breathing(intensity: state.permissions.microphone ? 0.02 : 0.05, duration: 1.5)
            }
            .onAppear {
                if !state.permissions.microphone {
                    withAnimation(AppAnimation.breathing(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulsePhase = 1
                    }
                }
            }

            VStack(spacing: 8) {
                Text("Microphone Access")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Required to record your voice.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }

            VStack(spacing: 12) {
                if state.permissions.microphone {
                    StatusBadge(granted: true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button("Grant Access") {
                        state.requestMicrophonePermission()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Open System Settings") {
                        state.openMicrophoneSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, 8)
            .animation(AppAnimation.stateChange, value: state.permissions.microphone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var pulsingRings: some View {
        ForEach(0..<3) { index in
            let baseSize = 80 + CGFloat(index) * 30
            let size = baseSize + pulsePhase * 20
            let opacity = 1 - pulsePhase * 0.3 * CGFloat(index + 1)
            let colorOpacity = 0.3 - Double(index) * 0.08
            
            Circle()
                .stroke(Color.brandPrimary.opacity(colorOpacity), lineWidth: 2)
                .frame(width: size, height: size)
                .opacity(opacity)
        }
    }
}
