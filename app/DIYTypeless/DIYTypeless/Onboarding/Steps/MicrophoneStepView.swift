import SwiftUI
import DIYTypelessCore

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 20) {
            PermissionIcon(
                icon: "mic.fill",
                granted: state.permissions.microphone
            )
            .frame(height: 104)
            .breathing(intensity: 0.018, duration: 3.6)
            .opacity(state.permissions.microphone ? 1.0 : 0.85)

            VStack(spacing: 8) {
                Text("Microphone Access")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Required to record your voice.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            OnboardingSurfaceCard {
                if state.permissions.microphone {
                    StatusBadge(granted: true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button("Grant Access") {
                        state.requestMicrophonePermission()
                    }
                    .buttonStyle(EnhancedSecondaryButtonStyle())

                    Button("Open System Settings") {
                        state.openMicrophoneSettings()
                    }
                    .quietLinkButton()
                }
            }
            .animation(AppAnimation.stateChange, value: state.permissions.microphone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
