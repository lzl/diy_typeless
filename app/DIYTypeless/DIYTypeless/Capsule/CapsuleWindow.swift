import AppKit
import Observation
import SwiftUI

private class CapsulePanel: NSPanel {
    var onEscDown: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == 53 {
                onEscDown?()
            }
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
final class CapsuleWindowController {
    private let panel: CapsulePanel
    private var observation: Any?

    init(state: RecordingState) {
        let hosting = NSHostingController(rootView: CapsuleView(state: state))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear

        // Let SwiftUI determine the actual size; we provide a reasonable initial size
        panel = CapsulePanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: CapsuleView.capsuleHeight + 14),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Allow the content view to determine its preferred size
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting.view
        panel.orderOut(nil)

        panel.onEscDown = { [weak state] in
            state?.handleCancel()
        }

        state.onWillDeliverText = { [weak panel] in
            panel?.resignKey()
        }

        // Use Observation framework for @Observable state
        startObserving(state: state)

        // Initial visibility update
        updateVisibility(for: state.capsuleState)
    }

    private func startObserving(state: RecordingState) {
        // withObservationTracking is one-shot, need to recursively re-register
        func observe() {
            _ = withObservationTracking {
                state.capsuleState
            } onChange: { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.updateVisibility(for: state.capsuleState)
                    observe() // Re-register for next change
                }
            }
        }
        observe()
    }

    private func updateVisibility(for state: CapsuleState) {
        if case .hidden = state {
            panel.orderOut(nil)
            return
        }

        // Defer positioning to next run loop to allow SwiftUI layout to complete
        DispatchQueue.main.async { [weak self] in
            self?.positionWindow()
        }
        panel.alphaValue = 1.0

        switch state {
        case .recording, .transcribing, .polishing:
            panel.ignoresMouseEvents = true
            panel.orderFrontRegardless()
            panel.makeKey()
        default:
            panel.resignKey()
            panel.orderFrontRegardless()
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        // Let the content view determine its size
        let contentSize = panel.contentView?.fittingSize ?? CGSize(width: 200, height: CapsuleView.capsuleHeight)
        let width = max(contentSize.width, CapsuleView.minCapsuleWidth)
        let height: CGFloat = CapsuleView.capsuleHeight + 14 // padding for window chrome

        let x = frame.midX - width / 2
        let y = frame.minY + 24
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
