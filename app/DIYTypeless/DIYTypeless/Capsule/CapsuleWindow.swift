import AppKit
import Combine
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
    private var cancellable: AnyCancellable?

    init(state: RecordingState) {
        let hosting = NSHostingController(rootView: CapsuleView(state: state))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear

        panel = CapsulePanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
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

        cancellable = state.$capsuleState
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.updateVisibility(for: newState)
            }
    }

    private func updateVisibility(for state: CapsuleState) {
        if case .hidden = state {
            panel.orderOut(nil)
            return
        }

        positionWindow()
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
        let width: CGFloat = 180
        let height: CGFloat = 50
        let x = frame.midX - width / 2
        let y = frame.minY + 24
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
