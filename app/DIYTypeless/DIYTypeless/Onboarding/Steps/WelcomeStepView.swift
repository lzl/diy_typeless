import SwiftUI

struct WelcomeStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 8) {
                Text("DIY Typeless")
                    .font(.system(size: 28, weight: .semibold))

                Text("Voice to polished text, instantly.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "keyboard.fill", text: "Hold Fn to record")
                FeatureRow(icon: "waveform", text: "Transcribe with Groq Whisper")
                FeatureRow(icon: "sparkles", text: "Polish with Gemini")
                FeatureRow(icon: "doc.on.clipboard", text: "Paste or copy instantly")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 14))
        }
    }
}
