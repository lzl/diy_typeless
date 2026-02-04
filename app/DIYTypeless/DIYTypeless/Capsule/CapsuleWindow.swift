import AppKit
import Combine
import SwiftUI

@MainActor
final class CapsuleWindowController {
    private let window: NSWindow
    private var cancellable: AnyCancellable?

    init(state: RecordingState) {
        let hosting = NSHostingController(rootView: CapsuleView(state: state))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 64),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = hosting.view
        window.orderOut(nil)

        cancellable = state.$capsuleState
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.updateVisibility(for: newState)
            }
    }

    private func updateVisibility(for state: CapsuleState) {
        if case .hidden = state {
            window.orderOut(nil)
            return
        }

        positionWindow()
        window.alphaValue = 1.0
        window.orderFrontRegardless()
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let width: CGFloat = 420
        let height: CGFloat = 64
        let x = frame.midX - width / 2
        let y = frame.minY + 28
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
