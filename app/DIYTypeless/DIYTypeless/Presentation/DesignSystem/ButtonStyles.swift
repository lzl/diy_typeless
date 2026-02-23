import SwiftUI

// MARK: - Button Styles
// Comprehensive button interaction system with micro-interactions

// MARK: - Primary Button Style (Enhanced)
struct EnhancedPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(for: configuration), lineWidth: 1)
            )
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(AppAnimation.micro, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isEnabled)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isEnabled ? .white : .textMuted
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .brandPrimary.opacity(0.3)
        }
        if configuration.isPressed {
            return .brandPrimary.opacity(0.7)
        }
        if isHovered {
            return .brandPrimaryLight
        }
        return .brandPrimary
    }

    private func borderColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .clear
        }
        if configuration.isPressed {
            return .brandPrimary.opacity(0.5)
        }
        if isHovered {
            return .brandPrimaryLight.opacity(0.5)
        }
        return .brandPrimary.opacity(0.3)
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        if !isEnabled {
            return 1.0
        }
        return configuration.isPressed ? 0.96 : 1.0
    }

    private func opacity(for configuration: Configuration) -> Double {
        if !isEnabled {
            return 0.6
        }
        return configuration.isPressed ? 0.85 : 1.0
    }
}

// MARK: - Secondary Button Style (Enhanced)
struct EnhancedSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(for: configuration), lineWidth: 1)
            )
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(AppAnimation.micro, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isEnabled)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isEnabled ? .textPrimary : .textMuted
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return Color(nsColor: .quaternarySystemFill).opacity(0.5)
        }
        if configuration.isPressed {
            return Color(nsColor: .tertiarySystemFill)
        }
        if isHovered {
            return Color(nsColor: .secondarySystemFill)
        }
        return Color(nsColor: .quaternarySystemFill)
    }

    private func borderColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return Color(nsColor: .separatorColor).opacity(0.5)
        }
        if configuration.isPressed {
            return Color(nsColor: .separatorColor)
        }
        if isHovered {
            return Color(nsColor: .separatorColor)
        }
        return Color(nsColor: .separatorColor).opacity(0.5)
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        if !isEnabled {
            return 1.0
        }
        return configuration.isPressed ? 0.96 : 1.0
    }

    private func opacity(for configuration: Configuration) -> Double {
        if !isEnabled {
            return 0.5
        }
        return configuration.isPressed ? 0.85 : 1.0
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(for: configuration), lineWidth: 1)
            )
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(AppAnimation.micro, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isEnabled)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isEnabled ? .error : .textMuted
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .error.opacity(0.2)
        }
        if configuration.isPressed {
            return .error.opacity(0.6)
        }
        if isHovered {
            return .error.opacity(0.8)
        }
        return .error.opacity(0.5)
    }

    private func borderColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .clear
        }
        if configuration.isPressed {
            return .error.opacity(0.4)
        }
        if isHovered {
            return .error.opacity(0.6)
        }
        return .error.opacity(0.3)
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        if !isEnabled {
            return 1.0
        }
        return configuration.isPressed ? 0.96 : 1.0
    }

    private func opacity(for configuration: Configuration) -> Double {
        if !isEnabled {
            return 0.5
        }
        return configuration.isPressed ? 0.85 : 1.0
    }
}

// MARK: - Icon Button Style (Enhanced)
struct EnhancedIconButtonStyle: ButtonStyle {
    let iconSize: CGFloat
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    init(iconSize: CGFloat = 20) {
        self.iconSize = iconSize
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(foregroundColor)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(backgroundColor(for: configuration))
            )
            .overlay(
                Circle()
                    .stroke(borderColor(for: configuration), lineWidth: 1)
            )
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(AppAnimation.micro, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isEnabled)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isEnabled ? (isHovered ? .white : .textSecondary) : .textMuted
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .clear
        }
        if configuration.isPressed {
            return Color(nsColor: .tertiarySystemFill)
        }
        if isHovered {
            return Color(nsColor: .quaternarySystemFill)
        }
        return .clear
    }

    private func borderColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .clear
        }
        if configuration.isPressed {
            return Color(nsColor: .separatorColor)
        }
        if isHovered {
            return Color(nsColor: .separatorColor).opacity(0.5)
        }
        return .clear
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        if !isEnabled {
            return 1.0
        }
        return configuration.isPressed ? 0.9 : 1.0
    }

    private func opacity(for configuration: Configuration) -> Double {
        if !isEnabled {
            return 0.4
        }
        return configuration.isPressed ? 0.8 : 1.0
    }
}

// MARK: - Menu Bar Button Style
struct MenuBarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(AppAnimation.micro, value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        isEnabled ? .textPrimary : .textMuted
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if !isEnabled {
            return .clear
        }
        if configuration.isPressed {
            return Color(nsColor: .tertiarySystemFill)
        }
        if isHovered {
            return Color(nsColor: .quaternarySystemFill)
        }
        return .clear
    }

    private func scale(for configuration: Configuration) -> CGFloat {
        if !isEnabled {
            return 1.0
        }
        return configuration.isPressed ? 0.98 : 1.0
    }

    private func opacity(for configuration: Configuration) -> Double {
        if !isEnabled {
            return 0.5
        }
        return configuration.isPressed ? 0.9 : 1.0
    }
}

// MARK: - View Extensions for Button Styles

extension View {
    /// Applies enhanced primary button style with full micro-interactions
    func enhancedPrimaryButton() -> some View {
        buttonStyle(EnhancedPrimaryButtonStyle())
    }

    /// Applies enhanced secondary button style with full micro-interactions
    func enhancedSecondaryButton() -> some View {
        buttonStyle(EnhancedSecondaryButtonStyle())
    }

    /// Applies destructive button style for delete/danger actions
    func destructiveButton() -> some View {
        buttonStyle(DestructiveButtonStyle())
    }

    /// Applies enhanced icon button style with full micro-interactions
    func enhancedIconButton(size: CGFloat = 20) -> some View {
        buttonStyle(EnhancedIconButtonStyle(iconSize: size))
    }

    /// Applies menu bar button style
    func menuBarButton() -> some View {
        buttonStyle(MenuBarButtonStyle())
    }
}
