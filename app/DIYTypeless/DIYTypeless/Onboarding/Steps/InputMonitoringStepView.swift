import SwiftUI

struct InputMonitoringStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            PermissionIcon(
                icon: "keyboard.fill",
                granted: true
            )

            VStack(spacing: 8) {
                Text("Fn Key Trigger")
                    .font(.system(size: 24, weight: .semibold))

                Text("Hold Fn to record. Release Fn to finish.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            StatusBadge(granted: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
