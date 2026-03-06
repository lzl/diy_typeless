import SwiftUI
import DIYTypelessCore

struct CompletionStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 20) {
            OnboardingIconBadge(systemName: "checkmark.circle.fill", tone: .success)

            VStack(spacing: 8) {
                Text("All Set")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text("DIY Typeless is ready to use.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
            }

            OnboardingSurfaceCard(alignment: .leading) {
                Text("How it works")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.linkQuiet)

                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(step: "1", text: "Hold Fn to record")
                    UsageRow(step: "2", text: "Release to transcribe and polish")
                    UsageRow(step: "3", text: "Text is pasted or copied")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UsageRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.16))
                )
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
