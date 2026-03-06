import SwiftUI
import DIYTypelessCore

struct WelcomeStepView: View {
    @Bindable var state: OnboardingState
    @State private var gradientPhase: CGFloat = 0

    private var dynamicGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandPrimary.opacity(0.92),
                Color.brandAccent.opacity(0.72),
                Color.brandPrimaryLight.opacity(0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(dynamicGradient)
                    .blur(radius: 22)
                    .frame(width: 116, height: 116)
                    .opacity(0.16 + gradientPhase * 0.04)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: gradientPhase)

                OnboardingIconBadge(systemName: "waveform.circle.fill", size: 92)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
                            .padding(7)
                    }
                    .scaleEffect(1.0 + gradientPhase * 0.015)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: gradientPhase)
            }
            .frame(height: 110)
            .onAppear { gradientPhase = 1 }
            .onDisappear { gradientPhase = 0 }

            VStack(spacing: 8) {
                Text("DIY Typeless")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("Voice to polished text, instantly.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
            }

            OnboardingSurfaceCard(alignment: .leading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What happens")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.linkQuiet)

                    OnboardingDetailRow(systemName: "globe", text: "Hold Fn to record")
                    OnboardingDetailRow(systemName: "waveform", text: "Transcribe with Whisper")
                    OnboardingDetailRow(systemName: "sparkles", text: "Polish with Gemini")
                    OnboardingDetailRow(systemName: "doc.on.clipboard", text: "Paste or copy instantly")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
