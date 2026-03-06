import SwiftUI
import DIYTypelessCore

struct GeminiKeyStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Gemini API Key",
            subtitle: "Polishes your transcript into clean text."
        ) {
            OnboardingIconBadge(systemName: "sparkles")
        } content: {
            OnboardingSurfaceCard(alignment: .leading, padding: 16) {
                ProviderConsoleLink {
                    state.openProviderConsole(for: .gemini)
                }

                VStack(spacing: 14) {
                    SecureField("Enter your Gemini API key", text: $state.geminiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appSurfaceSubtle)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.appBorderSubtle.opacity(0.7), lineWidth: 1)
                        )

                    HStack(spacing: 12) {
                        Button("Validate") {
                            state.validateGeminiKey()
                        }
                        .buttonStyle(EnhancedSecondaryButtonStyle())
                        .disabled(state.geminiValidation == .validating || state.geminiKey.isEmpty)

                        ValidationStatusView(state: state.geminiValidation)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
