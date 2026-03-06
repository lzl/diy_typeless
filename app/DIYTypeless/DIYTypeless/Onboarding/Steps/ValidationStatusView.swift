import SwiftUI
import DIYTypelessCore

struct ValidationStatusView: View {
    let state: ValidationState
    @State private var shakeTrigger = 0
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 7) {
                ProgressView()
                    .scaleEffect(0.65)
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandAccent))
                Text("Validating...")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.appSurfaceSubtle)
            )
            .transition(.opacity)
        case .success:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.success)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        checkmarkScale = 0
                        withAnimation(AppAnimation.pageTransition) {
                            checkmarkScale = 1
                        }
                    }
                Text("Verified")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.success)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.success.opacity(0.12))
            )
            .transition(.opacity)
        case .failure(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.error)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.error.opacity(0.10))
                )
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
                .fill(granted ? Color.success.opacity(0.12) : Color.brandPrimary.opacity(0.12))
                .frame(width: 86, height: 86)
            
            if granted {
                Circle()
                    .stroke(Color.success.opacity(0.24), lineWidth: 1.2)
                    .frame(width: 98, height: 98)
                    .scaleEffect(1.0 + glowPhase * 0.05)
                    .opacity(1.0 - glowPhase * 0.35)
                    .onAppear {
                        withAnimation(AppAnimation.breathing(duration: 3.4)) {
                            glowPhase = 1
                        }
                    }
            }

            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(granted ? Color.success : Color.brandPrimary)
        }
        .shadow(color: (granted ? Color.success : Color.brandPrimary).opacity(0.08), radius: 16, x: 0, y: 8)
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
        .foregroundStyle(granted ? Color.success : Color.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(granted ? Color.success.opacity(0.12) : Color.appSurfaceSubtle)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    granted ? Color.success.opacity(0.18) : Color.appBorderSubtle.opacity(0.6),
                    lineWidth: 1
                )
        )
        .scaleEffect(scale)
        .onAppear {
            withAnimation(AppAnimation.pageTransition) {
                scale = 1.0
            }
        }
    }
}
