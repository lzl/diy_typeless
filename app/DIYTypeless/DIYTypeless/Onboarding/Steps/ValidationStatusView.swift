import SwiftUI

struct ValidationStatusView: View {
    let state: ValidationState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Validating...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        case .success:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Key verified")
                    .font(.footnote)
                    .foregroundColor(.green)
            }
        case .failure(let message):
            Text(message)
                .font(.footnote)
                .foregroundColor(.red)
        }
    }
}
