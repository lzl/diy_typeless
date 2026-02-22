import SwiftUI

struct ValidationStatusView: View {
    let state: ValidationState
    @State private var shakeTrigger = 0
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                Text("Validating...")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            .transition(.opacity)
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.success)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        checkmarkScale = 0
                        withAnimation(AppAnimation.pageTransition) {
                            checkmarkScale = 1
                        }
                    }
                Text("Verified")
                    .font(.system(size: 12))
                    .foregroundColor(.success)
            }
            .transition(.opacity)
        case .failure(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.error)
                .lineLimit(2)
                .shake(intensity: 3)
                .transition(.opacity)
        }
    }
}

struct PermissionIcon: View {
    let icon: String
    let granted: Bool
    @State private var glowPhase: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(granted ? Color.success.opacity(0.15) : Color.brandPrimary.opacity(0.1))
                .frame(width: 80, height: 80)
            
            if granted {
                Circle()
                    .stroke(Color.success.opacity(0.3), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(1.0 + glowPhase * 0.1)
                    .opacity(1.0 - glowPhase * 0.5)
                    .onAppear {
                        withAnimation(AppAnimation.breathing(duration: 2.0)) {
                            glowPhase = 1
                        }
                    }
            }

            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(granted ? .success : .brandPrimary)
        }
    }
}

struct StatusBadge: View {
    let granted: Bool
    @State private var scale: CGFloat = 0.8

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
            Text(granted ? "Granted" : "Not granted")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(granted ? .success : .textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(granted ? Color.success.opacity(0.1) : Color.textSecondary.opacity(0.1))
        )
        .scaleEffect(scale)
        .onAppear {
            withAnimation(AppAnimation.pageTransition) {
                scale = 1.0
            }
        }
    }
}
