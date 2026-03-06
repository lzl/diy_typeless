import SwiftUI
import DIYTypelessCore

struct GroqKeyStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        OnboardingStepScaffold(
            title: "Groq API Key",
            subtitle: "Powers fast speech-to-text with Whisper."
        ) {
            OnboardingIconBadge {
                OnboardingGroqLogoGlyph()
            }
        } content: {
            OnboardingSurfaceCard(alignment: .leading, padding: 16) {
                ProviderConsoleLink {
                    state.openProviderConsole(for: .groq)
                }

                VStack(spacing: 14) {
                    SecureField("Enter your Groq API key", text: $state.groqKey)
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
                            state.validateGroqKey()
                        }
                        .buttonStyle(EnhancedSecondaryButtonStyle())
                        .disabled(state.groqValidation == .validating || state.groqKey.isEmpty)

                        ValidationStatusView(state: state.groqValidation)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
