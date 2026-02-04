import SwiftUI

struct AccessibilityStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "hand.raised.fill",
            iconColor: .blue,
            title: "Accessibility Access",
            description: "This lets DIY Typeless paste text into the focused app."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PermissionIndicator(title: "Accessibility", granted: state.permissions.accessibility)
                HStack(spacing: 12) {
                    Button("Request Accessibility Access") {
                        state.requestAccessibilityPermission()
                    }
                    Button("Open System Settings") {
                        state.openAccessibilitySettings()
                    }
                }
                Text("When prompted, enable DIY Typeless under Accessibility.")
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
                .disabled(!state.permissions.accessibility)
            }
        }
    }
}
