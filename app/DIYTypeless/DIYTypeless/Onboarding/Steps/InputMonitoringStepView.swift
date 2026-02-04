import SwiftUI

struct InputMonitoringStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            PermissionIcon(
                icon: "keyboard.fill",
                granted: state.permissions.inputMonitoring
            )

            VStack(spacing: 8) {
                Text("Input Monitoring")
                    .font(.system(size: 24, weight: .semibold))

                Text("Required to detect the Right Option key.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                if state.permissions.inputMonitoring {
                    if state.needsRestart {
                        Text("Restart required to activate.")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)

                        Button("Restart App") {
                            state.requestRestart()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        StatusBadge(granted: true)
                    }
                } else {
                    Button("Grant Access") {
                        state.requestInputMonitoringPermission()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Open System Settings") {
                        state.openInputMonitoringSettings()
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
