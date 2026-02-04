import SwiftUI

struct InputMonitoringStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "keyboard.fill",
            iconColor: .purple,
            title: "Input Monitoring",
            description: "DIY Typeless listens for the Right Option key to start recording."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PermissionIndicator(title: "Input Monitoring", granted: state.permissions.inputMonitoring)
                HStack(spacing: 12) {
                    Button("Request Input Monitoring") {
                        state.requestInputMonitoringPermission()
                    }
                    Button("Open System Settings") {
                        state.openInputMonitoringSettings()
                    }
                }

                if state.needsRestart {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restart required")
                            .font(.subheadline.bold())
                        Text("Input Monitoring only activates after a restart.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("Restart App") {
                            state.requestRestart()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 6)
                }
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
                .disabled(!state.permissions.inputMonitoring)
            }
        }
    }
}
