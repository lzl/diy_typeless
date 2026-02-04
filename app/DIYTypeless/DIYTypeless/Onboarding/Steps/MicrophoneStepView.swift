import SwiftUI

struct MicrophoneStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            PermissionIcon(
                icon: "mic.fill",
                granted: state.permissions.microphone
            )

            VStack(spacing: 8) {
                Text("Microphone Access")
                    .font(.system(size: 24, weight: .semibold))

                Text("Required to record your voice.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                if state.permissions.microphone {
                    StatusBadge(granted: true)
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
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
