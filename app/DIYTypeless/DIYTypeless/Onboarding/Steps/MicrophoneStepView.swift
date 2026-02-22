import SwiftUI

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            PermissionIcon(
                icon: "mic.fill",
                granted: state.permissions.microphone
            )
            .frame(height: 100)
            .breathing(intensity: 0.03, duration: 3.0)
            .opacity(state.permissions.microphone ? 1.0 : 0.7)

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
}
