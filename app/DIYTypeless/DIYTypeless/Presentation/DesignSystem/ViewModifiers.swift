import SwiftUI

// MARK: - Glassmorphism Modifier
/// Creates a glass-like translucent background effect
struct Glassmorphism: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material

    init(cornerRadius: CGFloat = 12, material: Material = .ultraThinMaterial) {
        self.cornerRadius = cornerRadius
        self.material = material
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.2))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.glassBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Card Container Modifier
/// Standard card container with consistent styling
struct CardContainer: ViewModifier {
    let padding: CGFloat
    let backgroundColor: Color
    let hasShadow: Bool

    init(padding: CGFloat = 16, backgroundColor: Color = .appSurface, hasShadow: Bool = true) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.hasShadow = hasShadow
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(
                color: hasShadow ? .black.opacity(0.2) : .clear,
                radius: hasShadow ? 8 : 0,
                x: 0,
                y: hasShadow ? 4 : 0
            )
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if configuration.isPressed {
            return .brandPrimary.opacity(0.8)
        }
        if isHovered {
            return .brandPrimaryLight
        }
        return .brandPrimary
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(for: configuration))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if configuration.isPressed {
            return .white.opacity(0.15)
        }
        if isHovered {
            return .white.opacity(0.12)
        }
        return .white.opacity(0.1)
    }
}

// MARK: - Ghost Button Style
struct GhostButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isHovered ? .white : .textSecondary)
            .padding(.horizontal, .sm)
            .padding(.vertical, .xs)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? .white.opacity(0.1) : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    let iconSize: CGFloat
    @State private var isHovered = false

    init(iconSize: CGFloat = 20) {
        self.iconSize = iconSize
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(isHovered ? .white : .textSecondary)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isHovered ? .white.opacity(0.1) : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Progress Bar Modifier
struct AnimatedProgressBar: ViewModifier {
    let progress: Double
    let color: Color
    let height: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * progress))
                    .animation(AppAnimation.progressFill, value: progress)

                // Glow effect at leading edge
                if progress > 0 {
                    Circle()
                        .fill(color)
                        .frame(width: height * 2, height: height * 2)
                        .blur(radius: 4)
                        .offset(x: geometry.size.width * progress - height)
                        .opacity(0.5)
                        .animation(AppAnimation.progressFill, value: progress)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies glassmorphism effect
    func glassmorphism(cornerRadius: CGFloat = 12, material: Material = .ultraThinMaterial) -> some View {
        modifier(Glassmorphism(cornerRadius: cornerRadius, material: material))
    }

    /// Wraps view in a standard card container
    func cardContainer(padding: CGFloat = 16, backgroundColor: Color = .appSurface, hasShadow: Bool = true) -> some View {
        modifier(CardContainer(padding: padding, backgroundColor: backgroundColor, hasShadow: hasShadow))
    }

    /// Applies primary button style
    func primaryButton() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    /// Applies secondary button style
    func secondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    /// Applies ghost button style
    func ghostButton() -> some View {
        buttonStyle(GhostButtonStyle())
    }

    /// Applies icon button style
    func iconButton(size: CGFloat = 20) -> some View {
        buttonStyle(IconButtonStyle(iconSize: size))
    }
}
