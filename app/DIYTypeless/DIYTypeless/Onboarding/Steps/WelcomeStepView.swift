import SwiftUI

struct WelcomeStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "sparkles",
            iconColor: .orange,
            title: "Welcome to DIY Typeless",
            description: "Hold the Right Option key, speak naturally, and get polished text pasted into your active app."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Record with a single key hold.", systemImage: "option")
                Label("Transcribe with Groq Whisper.", systemImage: "waveform")
                Label("Polish with Gemini.", systemImage: "sparkles")
                Label("Paste or copy instantly.", systemImage: "doc.on.clipboard")
            }
            .font(.subheadline)
        } actions: {
            HStack {
                Spacer()
                Button("Get Started") {
                    state.goNext()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
