import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    var onClose: (() -> Void)?

    init(state: OnboardingState) {
        let hosting = NSHostingController(rootView: OnboardingWindow(state: state))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
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
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

struct OnboardingWindow: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 1.0),
                    Color(red: 0.94, green: 0.98, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                header
                stepView
            }
            .padding(32)
        }
        .frame(minWidth: 720, minHeight: 520)
        .animation(.easeInOut(duration: 0.2), value: state.step)
    }

    private var header: some View {
        HStack {
            Text("Step \(state.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
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
}

struct OnboardingCard<Content: View, Actions: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let content: Content
    let actions: Actions

    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(iconColor)
                .padding(.top, 8)

            Text(title)
                .font(.system(size: 28, weight: .semibold))

            Text(description)
                .foregroundColor(.secondary)

            content

            Spacer()

            actions
        }
        .padding(36)
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

struct PermissionIndicator: View {
    let title: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(granted ? Color.clear : Color.secondary, lineWidth: 1)
                .background(Circle().fill(granted ? Color.green : Color.clear))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(granted ? "Granted" : "Not granted")
                .font(.caption)
                .foregroundColor(granted ? .green : .secondary)
        }
    }
}
