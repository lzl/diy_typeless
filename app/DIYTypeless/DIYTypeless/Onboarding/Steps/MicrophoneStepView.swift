import SwiftUI

struct MicrophoneStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "mic.fill",
            iconColor: .red,
            title: "Microphone Access",
            description: "DIY Typeless needs access to your microphone to record your voice."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PermissionIndicator(title: "Microphone", granted: state.permissions.microphone)
                HStack(spacing: 12) {
                    Button("Request Microphone Access") {
                        state.requestMicrophonePermission()
                    }
                    Button("Open System Settings") {
                        state.openMicrophoneSettings()
                    }
                }
                Text("You can change this later in System Settings > Privacy & Security.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } actions: {
            HStack {
                Button("Back") {
                    state.goBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Next") {
                    state.goNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.permissions.microphone)
            }
        }
    }
}
