import SwiftUI

struct GroqKeyStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "waveform.circle.fill",
            iconColor: .pink,
            title: "Groq API Key",
            description: "Groq powers fast speech-to-text with Whisper."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Groq API Key", text: $state.groqKey)
                    .textFieldStyle(.roundedBorder)
                ValidationStatusView(state: state.groqValidation)
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
                    state.validateGroqKey()
                }
                .buttonStyle(.bordered)
                .disabled(state.groqValidation == .validating)

                Button("Next") {
                    state.goNext()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.groqValidation.isSuccess)
            }
        }
    }
}
