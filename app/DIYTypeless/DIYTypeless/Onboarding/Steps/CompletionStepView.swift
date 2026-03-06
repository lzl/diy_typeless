import SwiftUI
import DIYTypelessCore

struct CompletionStepView: View {
    @Bindable var state: OnboardingState
    let recording: RecordingState
    @State private var practiceText = ""
    @FocusState private var isPracticeEditorFocused: Bool
    @State private var displayedGuidance = CompletionPracticeGuidance.make(for: .hidden)
    @State private var lastSuccessGuidance: CompletionPracticeGuidance?
    @State private var lastSuccessTimestamp: Date?
    @State private var guidanceResetTask: Task<Void, Never>?

    var body: some View {
        OnboardingStepScaffold(
            title: "All Set",
            subtitle: "Try DIY Typeless in the field below.",
            layoutMode: .centered
        ) {
            OnboardingIconBadge(systemName: "checkmark.circle.fill")
        } content: {
            OnboardingSurfaceCard(alignment: .leading, padding: 16, minHeight: 228) {
                Text("Try it now")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.linkQuiet)

                Text("Click inside the box, hold Fn, say a short sentence, then release.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)

                TextField("Your polished text will appear here.", text: $practiceText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(CompletionPracticeLayout.lineCount, reservesSpace: true)
                    .focused($isPracticeEditorFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurfaceSubtle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appBorderSubtle.opacity(0.7), lineWidth: 1)
                )

                CompletionPracticeStatusView(
                    guidance: displayedGuidance
                )
            }
            .onAppear {
                updateDisplayedGuidance(for: recording.capsuleState)
                focusPracticeEditor()
            }
            .onDisappear {
                guidanceResetTask?.cancel()
            }
            .onChange(of: recording.capsuleState) { _, newValue in
                updateDisplayedGuidance(for: newValue)
                if case .done = newValue {
                    focusPracticeEditor()
                }
            }
        }
    }

    private func focusPracticeEditor() {
        DispatchQueue.main.async {
            isPracticeEditorFocused = true
        }
    }

    private func updateDisplayedGuidance(for capsuleState: CapsuleState) {
        guidanceResetTask?.cancel()

        let nextGuidance = CompletionPracticeGuidance.make(for: capsuleState)
        switch capsuleState {
        case .done:
            displayedGuidance = nextGuidance
            lastSuccessGuidance = nextGuidance
            lastSuccessTimestamp = Date()

        case .hidden:
            guard
                let lastSuccessGuidance,
                let lastSuccessTimestamp
            else {
                displayedGuidance = nextGuidance
                return
            }

            let elapsed = Date().timeIntervalSince(lastSuccessTimestamp)
            let remaining = CompletionPracticeGuidanceDisplayPolicy.successHoldDuration - elapsed
            guard remaining > 0 else {
                self.lastSuccessGuidance = nil
                self.lastSuccessTimestamp = nil
                displayedGuidance = nextGuidance
                return
            }

            displayedGuidance = lastSuccessGuidance
            guidanceResetTask = Task {
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.lastSuccessGuidance = nil
                    self.lastSuccessTimestamp = nil
                    displayedGuidance = CompletionPracticeGuidance.make(for: .hidden)
                }
            }

        default:
            lastSuccessGuidance = nil
            lastSuccessTimestamp = nil
            displayedGuidance = nextGuidance
        }
    }
}

private struct CompletionPracticeStatusView: View {
    let guidance: CompletionPracticeGuidance

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            Text(guidance.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch guidance.tone {
        case .active:
            ProgressView()
                .controlSize(.small)
                .tint(Color.brandPrimary)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.success)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.error)
        case .neutral:
            Image(systemName: "text.cursor")
                .foregroundStyle(Color.brandAccent)
        }
    }

    private var foregroundColor: Color {
        switch guidance.tone {
        case .neutral:
            return .textPrimary
        case .active:
            return .brandPrimary
        case .success:
            return .success
        case .error:
            return .error
        }
    }

    private var backgroundColor: Color {
        switch guidance.tone {
        case .neutral:
            return .appSurfaceSubtle
        case .active:
            return .brandPrimary.opacity(0.10)
        case .success:
            return .success.opacity(0.10)
        case .error:
            return .error.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch guidance.tone {
        case .neutral:
            return .appBorderSubtle.opacity(0.55)
        case .active:
            return .brandPrimary.opacity(0.16)
        case .success:
            return .success.opacity(0.16)
        case .error:
            return .error.opacity(0.18)
        }
    }
}
