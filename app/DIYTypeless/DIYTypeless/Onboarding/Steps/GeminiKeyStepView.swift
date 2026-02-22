import SwiftUI

struct GeminiKeyStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 8) {
                Text("Gemini API Key")
                    .font(.system(size: 24, weight: .semibold))

                Text("Polishes your transcript into clean text.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                SecureField("Enter your Gemini API key", text: $state.geminiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                HStack(spacing: 12) {
                    Button("Validate") {
                        state.validateGeminiKey()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(state.geminiValidation == .validating || state.geminiKey.isEmpty)

                    ValidationStatusView(state: state.geminiValidation)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
