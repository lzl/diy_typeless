import SwiftUI
import DIYTypelessCore

struct AccessibilityStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 20) {
            PermissionIcon(
                icon: "hand.raised.fill",
                granted: state.permissions.accessibility
            )
            .frame(height: 104)
            .breathing(intensity: 0.018, duration: 3.6)
            .opacity(state.permissions.accessibility ? 1.0 : 0.85)

            VStack(spacing: 8) {
                Text("Accessibility Access")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Required to paste text into apps.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            OnboardingSurfaceCard {
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
                    .quietLinkButton()
                }
            }
            .animation(AppAnimation.stateChange, value: state.permissions.accessibility)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
