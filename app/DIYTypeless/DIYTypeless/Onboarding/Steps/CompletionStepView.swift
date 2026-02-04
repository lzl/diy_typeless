import SwiftUI

struct CompletionStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("All Set")
                    .font(.system(size: 28, weight: .semibold))

                Text("DIY Typeless is ready to use.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                UsageRow(step: "1", text: "Hold Right Option to record")
                UsageRow(step: "2", text: "Release to transcribe and polish")
                UsageRow(step: "3", text: "Text is pasted or copied")
            }
            .padding(.top, 8)
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
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.system(size: 14))
        }
    }
}
