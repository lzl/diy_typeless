import SwiftUI

struct VoiceCommandResultLayerView: View {
    static let layerWidth: CGFloat = 560
    static let layerHeight: CGFloat = 232

    let state: RecordingState
    let layer: VoiceCommandResultLayerState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .cornerXLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.18),
                            Color(white: 0.12),
                            Color(white: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: .cornerXLarge, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                .padding(0.5)

            VStack(spacing: .md) {
                resultTextContainer
                actionRow
            }
            .padding(.md)
        }
        .frame(width: Self.layerWidth, height: Self.layerHeight)
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private var resultTextContainer: some View {
        ScrollView {
            Text(layer.text)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: .cornerLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: .cornerLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var actionRow: some View {
        HStack(spacing: .sm) {
            Button(layer.didCopy ? "Copied (C)" : "Copy (C)") {
                state.copyVoiceCommandResultLayerText()
            }
            .buttonStyle(CapsuleLayerButtonStyle(isAccent: layer.didCopy))

            Spacer()

            Button("Close (Esc)") {
                state.closeVoiceCommandResultLayer()
            }
            .buttonStyle(CapsuleLayerButtonStyle(isAccent: false))
        }
    }
}

private struct CapsuleLayerButtonStyle: ButtonStyle {
    let isAccent: Bool

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor(configuration))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor(configuration), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isAccent ? .white : Color.white.opacity(0.9)
    }

    private func backgroundColor(_ configuration: Configuration) -> Color {
        if isAccent {
            if configuration.isPressed {
                return Color.brandPrimary.opacity(0.65)
            }
            if isHovered {
                return Color.brandPrimaryLight.opacity(0.88)
            }
            return Color.brandPrimary.opacity(0.82)
        }
        if configuration.isPressed {
            return Color.white.opacity(0.16)
        }
        if isHovered {
            return Color.white.opacity(0.12)
        }
        return Color.white.opacity(0.08)
    }

    private func borderColor(_ configuration: Configuration) -> Color {
        if isAccent {
            return configuration.isPressed
                ? Color.brandPrimaryLight.opacity(0.4)
                : Color.brandPrimaryLight.opacity(0.65)
        }
        return Color.white.opacity(configuration.isPressed ? 0.2 : 0.25)
    }
}
