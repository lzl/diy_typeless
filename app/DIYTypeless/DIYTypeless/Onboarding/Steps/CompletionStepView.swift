import SwiftUI

struct CompletionStepView: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        OnboardingCard(
            icon: "checkmark.seal.fill",
            iconColor: .green,
            title: "You are all set",
            description: "DIY Typeless is ready to use."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How to use")
                    .font(.subheadline.bold())
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Hold the Right Option key to record.")
                    Text("2. Release to transcribe and polish.")
                    Text("3. The result is pasted into the focused app or copied.")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        } actions: {
            HStack {
                Button("Back") {
                    state.goBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Finish") {
                    state.complete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
