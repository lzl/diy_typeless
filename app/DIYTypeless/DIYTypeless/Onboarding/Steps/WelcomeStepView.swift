import SwiftUI

struct WelcomeStepView: View {
    @Bindable var state: OnboardingState
    @State private var gradientPhase: CGFloat = 0

    private var dynamicGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandPrimary,
                Color.brandAccent,
                Color.brandPrimaryLight,
                Color.brandAccentLight
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Animated background glow
                Circle()
                    .fill(dynamicGradient)
                    .blur(radius: 20)
                    .frame(width: 120, height: 120)
                    .opacity(0.3 + gradientPhase * 0.2)
                    .animation(AppAnimation.breathing(duration: 3.0), value: gradientPhase)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(dynamicGradient)
                    .symbolEffect(.bounce, options: .repeating)
            }
            .onAppear { gradientPhase = 1 }
            .onDisappear { gradientPhase = 0 }

            VStack(spacing: 8) {
                Text("DIY Typeless")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Voice to polished text, instantly.")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "globe", text: "Hold Fn to record")
                FeatureRow(icon: "waveform", text: "Transcribe with Whisper")
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
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.brandPrimary)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isHovered)
    }
}
