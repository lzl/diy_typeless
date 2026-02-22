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
    @Bindable var state: OnboardingState
    @State private var previousStep: OnboardingStep = .welcome

    private var asymmetricTransition: AnyTransition {
        let isForward = state.step.rawValue > previousStep.rawValue
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

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
        .onChange(of: state.step) { oldValue, newValue in
            previousStep = oldValue
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= state.step.rawValue ? Color.brandPrimary : Color.secondary.opacity(0.3))
                    .frame(width: step == state.step ? 24 : 8, height: 8)
                    .animation(AppAnimation.stateChange, value: state.step)
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .welcome:
            WelcomeStepView(state: state)
                .transition(asymmetricTransition)
        case .microphone:
            MicrophoneStepView(state: state)
                .transition(asymmetricTransition)
        case .accessibility:
            AccessibilityStepView(state: state)
                .transition(asymmetricTransition)
        case .groqKey:
            GroqKeyStepView(state: state)
                .transition(asymmetricTransition)
        case .geminiKey:
            GeminiKeyStepView(state: state)
                .transition(asymmetricTransition)
        case .completion:
            CompletionStepView(state: state)
                .transition(asymmetricTransition)
        }
    }

    private var navigationButtons: some View {
        HStack {
            if state.step != .welcome {
                Button("Back") {
                    withAnimation(AppAnimation.pageTransition) {
                        state.goBack()
                    }
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
                    withAnimation(AppAnimation.pageTransition) {
                        state.goNext()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!state.canProceed)
            }
        }
    }
}

// Button styles are now defined in Presentation/DesignSystem/ViewModifiers.swift
