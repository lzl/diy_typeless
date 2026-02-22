import SwiftUI

struct AccessibilityStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            PermissionIcon(
                icon: "hand.raised.fill",
                granted: state.permissions.accessibility
            )

            VStack(spacing: 8) {
                Text("Accessibility Access")
                    .font(.system(size: 24, weight: .semibold))

                Text("Required to paste text into apps.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                if state.permissions.accessibility {
                    StatusBadge(granted: true)
                } else {
                    Button("Grant Access") {
                        state.requestAccessibilityPermission()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Open System Settings") {
                        state.openAccessibilitySettings()
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
