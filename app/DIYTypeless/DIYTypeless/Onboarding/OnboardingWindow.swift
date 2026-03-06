import AppKit
import SwiftUI
import DIYTypelessCore

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    var onClose: (() -> Void)?

    init(state: OnboardingState) {
        let hosting = NSHostingController(rootView: OnboardingWindow(state: state))
        window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppSize.onboardingWidth,
                height: AppSize.onboardingHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DIY Typeless"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: AppSize.onboardingWidth,
            height: AppSize.onboardingHeight
        )
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
    @State private var transitionDirection: TransitionDirection = .forward

    enum TransitionDirection {
        case forward
        case backward
    }

    private var transition: AnyTransition {
        switch transitionDirection {
        case .forward:
            // Continue: current slides left, new comes from right
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            // Back: current slides right, new comes from left
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .appBackground,
                    .appBackgroundSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.glowPrimary)
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: -160, y: -120)

            Circle()
                .fill(Color.glowAccent)
                .frame(width: 220, height: 220)
                .blur(radius: 100)
                .offset(x: 180, y: 140)

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                stepView
                    .frame(
                        maxWidth: .infinity,
                        minHeight: OnboardingTheme.stepViewportMinHeight,
                        maxHeight: .infinity,
                        alignment: .top
                    )

                navigationButtons
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.appSurface.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.appBorderSubtle.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 18)
        }
        .padding(14)
        .frame(width: AppSize.onboardingWidth, height: AppSize.onboardingHeight)
        .background(Color.appBackground)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(indicatorColor(for: step))
                    .frame(width: step == state.step ? 28 : 10, height: 10)
                    .animation(AppAnimation.stateChange, value: state.step)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.appSurfaceSubtle)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.appBorderSubtle.opacity(0.65), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .welcome:
            WelcomeStepView(state: state)
                .transition(transition)
        case .microphone:
            MicrophoneStepView(state: state)
                .transition(transition)
        case .accessibility:
            AccessibilityStepView(state: state)
                .transition(transition)
        case .groqKey:
            GroqKeyStepView(state: state)
                .transition(transition)
        case .geminiKey:
            GeminiKeyStepView(state: state)
                .transition(transition)
        case .completion:
            CompletionStepView(state: state)
                .transition(transition)
        }
    }

    private var navigationButtons: some View {
        HStack {
            if state.step != .welcome {
                Button("Back") {
                    transitionDirection = .backward
                    withAnimation(AppAnimation.pageTransition) {
                        state.goBack()
                    }
                }
                .buttonStyle(EnhancedSecondaryButtonStyle())
            }

            Spacer()

            if state.step == .completion {
                Button("Finish") {
                    state.complete()
                }
                .buttonStyle(EnhancedPrimaryButtonStyle())
            } else {
                Button("Continue") {
                    transitionDirection = .forward
                    withAnimation(AppAnimation.pageTransition) {
                        state.goNext()
                    }
                }
                .buttonStyle(EnhancedPrimaryButtonStyle())
                .disabled(!state.canProceed)
            }
        }
    }

    private func indicatorColor(for step: OnboardingStep) -> Color {
        if step == state.step {
            return .brandPrimary
        }
        if step.rawValue < state.step.rawValue {
            return .brandAccent.opacity(0.65)
        }
        return .appBorderSubtle.opacity(0.7)
    }
}

// Button styles are now defined in Presentation/DesignSystem/ViewModifiers.swift
