import SwiftUI

enum OnboardingStepLayoutMode {
    case top
    case centered
}

enum OnboardingStepIconStyle {
    static let size: CGFloat = 88
    static let tintHex = AppTheme.brandPrimaryHex
    static let shadowOpacity = 0.0
}

struct OnboardingStepScaffold<Icon: View, Content: View>: View {
    let title: String
    let subtitle: String
    let iconHeight: CGFloat
    let contentSpacing: CGFloat
    let layoutMode: OnboardingStepLayoutMode
    let icon: Icon
    let content: Content

    init(
        title: String,
        subtitle: String,
        iconHeight: CGFloat = 110,
        contentSpacing: CGFloat = 24,
        layoutMode: OnboardingStepLayoutMode = .top,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconHeight = iconHeight
        self.contentSpacing = contentSpacing
        self.layoutMode = layoutMode
        self.icon = icon()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            icon
                .frame(height: iconHeight)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 16)

            content
                .padding(.top, contentSpacing)
                .frame(maxWidth: OnboardingTheme.contentColumnMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, layoutMode == .centered ? 12 : 0)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: layoutMode == .centered ? .center : .top
        )
    }
}

struct OnboardingSurfaceCard<Content: View>: View {
    let alignment: HorizontalAlignment
    let padding: CGFloat
    let minHeight: CGFloat
    @ViewBuilder let content: Content

    init(
        alignment: HorizontalAlignment = .center,
        padding: CGFloat = 18,
        minHeight: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.padding = padding
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 14) {
            content
        }
        .padding(padding)
        .frame(
            maxWidth: .infinity,
            minHeight: minHeight,
            alignment: alignment == .leading ? .leading : .center
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appSurfaceRaised.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appBorderSubtle.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}

struct OnboardingIconBadge<Content: View>: View {
    let size: CGFloat
    let tint: Color
    let content: Content

    init(
        size: CGFloat = OnboardingStepIconStyle.size,
        tint: Color = Color(hex: OnboardingStepIconStyle.tintHex),
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: size, height: size)

            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 1)
                .frame(width: size + 10, height: size + 10)

            content
                .foregroundStyle(tint)
                .frame(width: size * 0.4, height: size * 0.4)
        }
    }
}

extension OnboardingIconBadge where Content == AnyView {
    init(
        systemName: String,
        size: CGFloat = OnboardingStepIconStyle.size,
        tint: Color = Color(hex: OnboardingStepIconStyle.tintHex)
    ) {
        self.init(size: size, tint: tint) {
            AnyView(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.36, weight: .medium))
            )
        }
    }
}

enum GroqLogoMetadata {
    static let title = "Groq"
    static let path = "M12.036 2c-3.853-.035-7 3-7.036 6.781-.035 3.782 3.055 6.872 6.908 6.907h2.42v-2.566h-2.292c-2.407.028-4.38-1.866-4.408-4.23-.029-2.362 1.901-4.298 4.308-4.326h.1c2.407 0 4.358 1.915 4.365 4.278v6.305c0 2.342-1.944 4.25-4.323 4.279a4.375 4.375 0 01-3.033-1.252l-1.851 1.818A7 7 0 0012.029 22h.092c3.803-.056 6.858-3.083 6.879-6.816v-6.5C18.907 4.963 15.817 2 12.036 2z"
}

struct OnboardingGroqLogoGlyph: View {
    var body: some View {
        GroqLogoShape()
            .fill(style: FillStyle(eoFill: true))
            .accessibilityLabel(GroqLogoMetadata.title)
    }
}

private struct GroqLogoShape: Shape {
    private static let viewBox = CGSize(width: 24, height: 24)

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
        let xOffset = rect.midX - (Self.viewBox.width * scale) / 2
        let yOffset = rect.midY - (Self.viewBox.height * scale) / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: xOffset + x * scale, y: yOffset + y * scale)
        }

        var path = Path()
        path.move(to: point(12.036, 2))
        path.addCurve(to: point(5, 8.781), control1: point(8.183, 1.965), control2: point(5.036, 5))
        path.addCurve(to: point(11.908, 15.688), control1: point(4.965, 12.563), control2: point(8.055, 15.653))
        path.addLine(to: point(14.328, 15.688))
        path.addLine(to: point(14.328, 13.122))
        path.addLine(to: point(12.036, 13.122))
        path.addCurve(to: point(7.628, 8.892), control1: point(9.629, 13.15), control2: point(7.656, 11.256))
        path.addCurve(to: point(11.936, 4.566), control1: point(7.599, 6.53), control2: point(9.529, 4.594))
        path.addLine(to: point(12.036, 4.566))
        path.addCurve(to: point(16.401, 8.844), control1: point(14.443, 4.566), control2: point(16.394, 6.481))
        path.addLine(to: point(16.401, 15.149))
        path.addCurve(to: point(12.078, 19.428), control1: point(16.401, 17.491), control2: point(14.457, 19.399))
        path.addCurve(to: point(9.045, 18.176), control1: point(10.942859, 19.419953), control2: point(9.855288, 18.971011))
        path.addLine(to: point(7.194, 19.994))
        path.addCurve(to: point(12.029, 22), control1: point(8.485595, 21.262785), control2: point(10.218557, 21.981777))
        path.addLine(to: point(12.121, 22))
        path.addCurve(to: point(19, 15.184), control1: point(15.924, 21.944), control2: point(18.979, 18.917))
        path.addLine(to: point(19, 8.684))
        path.addCurve(to: point(12.036, 2), control1: point(18.907, 4.963), control2: point(15.817, 2))
        path.closeSubpath()
        return path
    }
}

struct OnboardingChecklistRow: View {
    let item: OnboardingChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandAccent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.brandAccent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(item.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurfaceSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appBorderSubtle.opacity(0.55), lineWidth: 1)
        )
    }
}
