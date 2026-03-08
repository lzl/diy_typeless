import AppKit
import SwiftUI
import DIYTypelessCore

enum OnboardingWindowChromeLayout {
    static let trafficLightButtons: [NSWindow.ButtonType] = [
        .closeButton,
        .miniaturizeButton,
        .zoomButton
    ]

    static func trafficLightOrigins(
        for buttonSizes: [NSWindow.ButtonType: CGSize],
        in titlebarHeight: CGFloat
    ) -> [NSWindow.ButtonType: CGPoint] {
        var origins: [NSWindow.ButtonType: CGPoint] = [:]
        var currentX = OnboardingTheme.windowTrafficLightsLeadingInset

        for buttonType in trafficLightButtons {
            guard let buttonSize = buttonSizes[buttonType] else {
                continue
            }
            origins[buttonType] = CGPoint(
                x: currentX,
                y: titlebarHeight - OnboardingTheme.windowTrafficLightsTopInset - buttonSize.height
            )
            currentX += buttonSize.width + OnboardingTheme.windowTrafficLightsSpacing
        }

        return origins
    }
}

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    var onClose: (() -> Void)?

    init(state: OnboardingState, recording: RecordingState) {
        let hosting = NSHostingController(rootView: OnboardingWindow(state: state, recording: recording))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppSize.onboardingWidth,
                height: AppSize.onboardingHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DIY Typeless"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: AppSize.onboardingWidth,
            height: AppSize.onboardingHeight
        )
        window.center()
        window.contentView = hosting.view
        super.init()
        configureWindowFrameAppearance()
        window.delegate = self
        scheduleTrafficLightsLayout()
    }

    func show() {
        // Switch to regular mode before activation so AppKit can promote this window reliably.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        configureWindowFrameAppearance()
        scheduleTrafficLightsLayout()
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

    func windowDidBecomeKey(_ notification: Notification) {
        configureWindowFrameAppearance()
        scheduleTrafficLightsLayout()
    }

    func windowDidResize(_ notification: Notification) {
        configureWindowFrameAppearance()
        scheduleTrafficLightsLayout()
    }

    private func scheduleTrafficLightsLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.layoutTrafficLights()
        }
    }

    private func configureWindowFrameAppearance() {
        guard let themeFrame = window.contentView?.superview else {
            return
        }

        themeFrame.wantsLayer = true
        themeFrame.layer?.backgroundColor = NSColor.clear.cgColor
        themeFrame.layer?.cornerRadius = OnboardingTheme.windowShellCornerRadius
        themeFrame.layer?.cornerCurve = .continuous
        themeFrame.layer?.masksToBounds = true
    }

    private func layoutTrafficLights() {
        var buttons: [NSWindow.ButtonType: NSButton] = [:]
        var buttonSizes: [NSWindow.ButtonType: CGSize] = [:]

        for buttonType in OnboardingWindowChromeLayout.trafficLightButtons {
            guard let button = window.standardWindowButton(buttonType) else {
                return
            }
            button.superview?.layoutSubtreeIfNeeded()
            buttons[buttonType] = button
            buttonSizes[buttonType] = button.frame.size
        }

        let titlebarHeight = buttons[.closeButton]?.superview?.bounds.height ?? 0
        let origins = OnboardingWindowChromeLayout.trafficLightOrigins(
            for: buttonSizes,
            in: titlebarHeight
        )
        for buttonType in OnboardingWindowChromeLayout.trafficLightButtons {
            guard let button = buttons[buttonType], let origin = origins[buttonType] else {
                continue
            }
            button.setFrameOrigin(origin)
        }
    }
}

struct OnboardingWindow: View {
    @Bindable var state: OnboardingState
    let recording: RecordingState
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

    private var windowShellShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: OnboardingTheme.windowShellCornerRadius,
            style: .continuous
        )
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
                    .padding(.bottom, 20)

                stepView
                    .frame(
                        maxWidth: .infinity,
                        minHeight: OnboardingTheme.stepViewportMinHeight,
                        maxHeight: .infinity,
                        alignment: .top
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: OnboardingTheme.stepViewportCornerRadius,
                            style: .continuous
                        )
                    )

                navigationButtons
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, OnboardingTheme.windowContentHorizontalPadding)
            .padding(.top, OnboardingTheme.windowContentTopPadding)
            .padding(.bottom, OnboardingTheme.windowContentBottomPadding)
        }
        .frame(width: AppSize.onboardingWidth, height: AppSize.onboardingHeight)
        .background(
            windowShellShape
                .fill(Color.appSurface.opacity(0.96))
        )
        .clipShape(windowShellShape)
        .padding(OnboardingTheme.windowOuterPadding)
        .background(Color.clear)
        .ignoresSafeArea()
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
            CompletionStepView(state: state, recording: recording)
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
