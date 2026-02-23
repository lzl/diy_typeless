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

            Button {
                if let url = URL(string: "https://aistudio.google.com/app/api-keys") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 0) {
                    Text("Don't have an API key? ")
                        .foregroundColor(.secondary)
                    Text("Get one here")
                        .foregroundColor(.accentColor)
                        .underline()
                }
                .font(.system(size: 13))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
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
