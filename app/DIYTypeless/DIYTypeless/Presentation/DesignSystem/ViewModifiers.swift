import SwiftUI

// NOTE: Button styles have been moved to ButtonStyles.swift
// Use EnhancedPrimaryButtonStyle, EnhancedSecondaryButtonStyle, etc. from that file.

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
}
