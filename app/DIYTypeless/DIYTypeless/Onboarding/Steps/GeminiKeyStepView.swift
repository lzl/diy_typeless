import SwiftUI

struct GeminiKeyStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "sparkles",
            iconColor: .teal,
            title: "Gemini API Key",
            description: "Gemini polishes your transcript into clean, readable text."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Gemini API Key", text: $state.geminiKey)
                    .textFieldStyle(.roundedBorder)
                ValidationStatusView(state: state.geminiValidation)
                Text("We validate your key with a lightweight API request.")
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

                Button("Validate Key") {
                    state.validateGeminiKey()
                }
                .buttonStyle(.bordered)
                .disabled(state.geminiValidation == .validating)

                Button("Next") {
                    state.goNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.geminiValidation.isSuccess)
            }
        }
    }
}
