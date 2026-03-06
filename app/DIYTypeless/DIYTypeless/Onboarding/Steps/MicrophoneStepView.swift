import SwiftUI
import DIYTypelessCore

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Microphone Access",
            subtitle: "Required to record your voice."
        ) {
            PermissionIcon(
                icon: "mic.fill",
                granted: state.permissions.microphone
            )
            .breathing(intensity: 0.018, duration: 3.6)
            .opacity(state.permissions.microphone ? 1.0 : 0.85)
        } content: {
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
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(AppAnimation.stateChange, value: state.permissions.microphone)
        }
    }
}
