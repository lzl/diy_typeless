import SwiftUI
import DIYTypelessCore

struct AccessibilityStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Accessibility Access",
            subtitle: "Required to paste text into apps."
        ) {
            OnboardingIconBadge(systemName: "hand.raised.fill")
        } content: {
            OnboardingSurfaceCard(padding: 20, minHeight: 156) {
                if state.permissions.accessibility {
                    VStack(spacing: 10) {
                        StatusBadge(granted: true)
                            .transition(.scale.combined(with: .opacity))

                        Text("Accessibility access is ready for text insertion.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("This lets DIY Typeless paste polished text back into the active app.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)

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
            }
            .animation(AppAnimation.stateChange, value: state.permissions.accessibility)
        }
    }
}
