import SwiftUI
import DIYTypelessCore

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Microphone Access",
            subtitle: "Required to record your voice."
        ) {
            OnboardingIconBadge(systemName: "mic.fill")
        } content: {
            OnboardingSurfaceCard(padding: 20, minHeight: 156) {
                if state.permissions.microphone {
                    VStack(spacing: 10) {
                        StatusBadge(granted: true)
                            .transition(.scale.combined(with: .opacity))

                        Text("Microphone access is ready for recording.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("We only use this to capture audio while you hold Fn.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)

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
            }
            .animation(AppAnimation.stateChange, value: state.permissions.microphone)
        }
    }
}
