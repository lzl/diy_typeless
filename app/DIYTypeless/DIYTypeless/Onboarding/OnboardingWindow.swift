import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    var onClose: (() -> Void)?

    init(state: OnboardingState) {
        let hosting = NSHostingController(rootView: OnboardingWindow(state: state))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DIY Typeless"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = hosting.view
        super.init()
        window.delegate = self
    }

    func show() {
        // Switch to regular mode before activation so AppKit can promote this window reliably.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
        // Switch back to accessory policy to hide Dock icon
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillClose(_ notification: Notification) {
        // Switch back to accessory policy when window closes
        NSApp.setActivationPolicy(.accessory)
        onClose?()
    }
}

struct OnboardingWindow: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 24)
                .padding(.bottom, 32)

            stepView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            navigationButtons
                .padding(.top, 24)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 40)
        .frame(minWidth: 480, minHeight: 440)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: state.step)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= state.step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: step == state.step ? 24 : 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .welcome:
            WelcomeStepView(state: state)
        case .microphone:
            MicrophoneStepView(state: state)
        case .accessibility:
            AccessibilityStepView(state: state)
        case .inputMonitoring:
            InputMonitoringStepView(state: state)
        case .groqKey:
            GroqKeyStepView(state: state)
        case .geminiKey:
            GeminiKeyStepView(state: state)
        case .completion:
            CompletionStepView(state: state)
        }
    }

    private var navigationButtons: some View {
        HStack {
            if state.step != .welcome {
                Button("Back") {
                    state.goBack()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()

            if state.step == .completion {
                Button("Finish") {
                    state.complete()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Continue") {
                    state.goNext()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!state.canProceed)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
