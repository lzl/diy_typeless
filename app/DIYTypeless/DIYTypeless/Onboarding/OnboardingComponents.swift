import SwiftUI

struct OnboardingStepScaffold<Icon: View, Content: View>: View {
    let title: String
    let subtitle: String
    let iconHeight: CGFloat
    let contentSpacing: CGFloat
    let icon: Icon
    let content: Content

    init(
        title: String,
        subtitle: String,
        iconHeight: CGFloat = 110,
        contentSpacing: CGFloat = 24,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconHeight = iconHeight
        self.contentSpacing = contentSpacing
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

struct OnboardingIconBadge: View {
    enum Tone {
        case accent
        case success
        case muted
    }

    let systemName: String
    let tone: Tone
    let size: CGFloat
    let tintOverride: Color?

    init(systemName: String, tone: Tone = .accent, size: CGFloat = 88, tint: Color? = nil) {
        self.systemName = systemName
        self.tone = tone
        self.size = size
        self.tintOverride = tint
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: size, height: size)

            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 1)
                .frame(width: size + 10, height: size + 10)

            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(tint)
        }
        .shadow(color: tint.opacity(0.10), radius: 18, x: 0, y: 8)
    }

    private var tint: Color {
        if let tintOverride {
            return tintOverride
        }
        switch tone {
        case .accent:
            return .brandPrimary
        case .success:
            return .success
        case .muted:
            return .brandAccent
        }
    }
}

struct OnboardingDetailRow: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandAccent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.brandAccent.opacity(0.12))
                )

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
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
