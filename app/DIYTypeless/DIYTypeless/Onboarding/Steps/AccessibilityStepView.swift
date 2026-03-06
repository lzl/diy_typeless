import SwiftUI
import DIYTypelessCore

struct AccessibilityStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Accessibility Access",
            subtitle: "Required to paste text into apps."
        ) {
            PermissionIcon(
                icon: "hand.raised.fill",
                granted: state.permissions.accessibility
            )
            .breathing(intensity: 0.018, duration: 3.6)
            .opacity(state.permissions.accessibility ? 1.0 : 0.85)
        } content: {
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
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(AppAnimation.stateChange, value: state.permissions.accessibility)
        }
    }
}
