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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Steps to enable:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Click \"Open System Settings\" below")
                            Text("2. Click the + button to add DIYTypeless")
                            Text("3. Check the box next to DIYTypeless")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    Button("Open System Settings") {
                        state.openInputMonitoringSettings()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Permission will be detected automatically.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
