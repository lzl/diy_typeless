import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecordingState.self) private var recordingState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status indicator section
            statusSection

            Divider()
                .padding(.vertical, 4)

            // Action buttons
            Button("Settings...") {
                appState.showOnboarding()
            }
            .menuBarButton()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .menuBarButton()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusSection: some View {
        HStack(spacing: 8) {
            statusIcon
                .frame(width: 16, height: 16)

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(statusColor)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(statusBackgroundColor)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch recordingState.capsuleState {
        case .recording:
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.error)
                .symbolEffect(.pulse, options: .repeating, value: true)
        case .transcribing:
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandPrimaryLight)
                .symbolEffect(.variableColor, options: .repeating, value: true)
        case .polishing:
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandAccentLight)
                .symbolEffect(.pulse, options: .repeating, value: true)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.success)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.warning)
        case .hidden:
            Image(systemName: "mic")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    private var statusText: String {
        switch recordingState.capsuleState {
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .polishing:
            return "Polishing..."
        case .done:
            return "Complete"
        case .error:
            return "Error"
        case .hidden:
            return "Ready"
        }
    }

    private var statusColor: Color {
        switch recordingState.capsuleState {
        case .recording:
            return .error
        case .transcribing:
            return .brandPrimaryLight
        case .polishing:
            return .brandAccentLight
        case .done:
            return .success
        case .error:
            return .warning
        case .hidden:
            return .textSecondary
        }
    }

    private var statusBackgroundColor: Color {
        switch recordingState.capsuleState {
        case .recording:
            return .error.opacity(0.15)
        case .transcribing:
            return .brandPrimary.opacity(0.15)
        case .polishing:
            return .brandAccent.opacity(0.15)
        case .done:
            return .success.opacity(0.15)
        case .error:
            return .warning.opacity(0.15)
        case .hidden:
            return .white.opacity(0.05)
        }
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environment(AppState())
        .environment(RecordingState(
            permissionRepository: SystemPermissionRepository(),
            apiKeyRepository: KeychainApiKeyRepository(),
            keyMonitoringRepository: SystemKeyMonitoringRepository(),
            textOutputRepository: SystemTextOutputRepository()
        ))
        .frame(width: 200)
        .background(Color.appBackground)
}
