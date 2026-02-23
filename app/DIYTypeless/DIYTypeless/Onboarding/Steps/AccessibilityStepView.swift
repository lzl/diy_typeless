import SwiftUI

struct AccessibilityStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            PermissionIcon(
                icon: "hand.raised.fill",
                granted: state.permissions.accessibility
            )
            .frame(height: 100)
            .breathing(intensity: 0.03, duration: 3.0)
            .opacity(state.permissions.accessibility ? 1.0 : 0.7)

            VStack(spacing: 8) {
                Text("Accessibility Access")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Required to paste text into apps.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }

            VStack(spacing: 12) {
                if state.permissions.accessibility {
                    StatusBadge(granted: true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button("Grant Access") {
                        state.requestAccessibilityPermission()
                    }
                    .buttonStyle(EnhancedSecondaryButtonStyle())

                    Button("Open System Settings") {
                        state.openAccessibilitySettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, 8)
            .animation(AppAnimation.stateChange, value: state.permissions.accessibility)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
