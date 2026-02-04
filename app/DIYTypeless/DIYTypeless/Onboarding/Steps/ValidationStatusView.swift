import SwiftUI

struct ValidationStatusView: View {
    let state: ValidationState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Validating...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                Text("Verified")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        case .failure(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.red)
                .lineLimit(2)
        }
    }
}

struct PermissionIcon: View {
    let icon: String
    let granted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(granted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                .frame(width: 80, height: 80)

            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(granted ? .green : .secondary)
        }
    }
}

struct StatusBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
            Text(granted ? "Granted" : "Not granted")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(granted ? .green : .secondary)
    }
}
