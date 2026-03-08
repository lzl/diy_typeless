import SwiftUI
import DIYTypelessCore

struct WelcomeStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "DIY Typeless",
            subtitle: "Voice to polished text, instantly.",
            iconHeight: 118,
            contentSpacing: 24
        ) {
            OnboardingIconBadge(systemName: "waveform")
        } content: {
            OnboardingSurfaceCard(alignment: .leading, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnboardingWelcomeContent.setupChecklistTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.linkQuiet)

                    ForEach(OnboardingWelcomeContent.setupChecklistItems, id: \.title) { item in
                        OnboardingChecklistRow(item: item)
                    }
                }
            }
        }
    }
}
