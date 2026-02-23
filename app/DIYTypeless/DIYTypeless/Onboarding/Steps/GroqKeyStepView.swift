import SwiftUI

struct GroqKeyStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)

            VStack(spacing: 8) {
                Text("Groq API Key")
                    .font(.system(size: 24, weight: .semibold))

                Text("Powers fast speech-to-text with Whisper.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Button {
                if let url = URL(string: "https://console.groq.com/keys") {
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
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            VStack(spacing: 16) {
                SecureField("Enter your Groq API key", text: $state.groqKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                HStack(spacing: 12) {
                    Button("Validate") {
                        state.validateGroqKey()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(state.groqValidation == .validating || state.groqKey.isEmpty)

                    ValidationStatusView(state: state.groqValidation)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
