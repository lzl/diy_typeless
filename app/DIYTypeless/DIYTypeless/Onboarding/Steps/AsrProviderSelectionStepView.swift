import SwiftUI

struct AsrProviderSelectionStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Speech Recognition Method")
                    .font(.system(size: 24, weight: .semibold))

                Text("Choose your preferred speech recognition engine")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                providerCard(
                    provider: .groq,
                    isSelected: state.asrProvider == .groq
                ) {
                    state.asrProvider = .groq
                }

                providerCard(
                    provider: .local,
                    isSelected: state.asrProvider == .local
                ) {
                    state.asrProvider = .local
                }
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func providerCard(provider: AsrProvider, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: provider == .groq ? "cloud.fill" : "cpu.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(provider.description)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
