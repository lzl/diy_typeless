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
