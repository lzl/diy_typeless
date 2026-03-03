import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

private class CapsulePanel: NSPanel {
    var onEscDown: (() -> Void)?
    var onCopyDown: (() -> Void)?
    var captureNonEscKeyDown: Bool = true

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == 53 {
                onEscDown?()
                return
            }
            if !captureNonEscKeyDown, isCopyKeyDown(event) {
                onCopyDown?()
                return
            }
            if captureNonEscKeyDown {
                return
            }
        }
        super.sendEvent(event)
    }

    private func isCopyKeyDown(_ event: NSEvent) -> Bool {
        let significantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedFlags: NSEvent.ModifierFlags = [.command, .option, .control]
        guard significantFlags.intersection(disallowedFlags).isEmpty else {
            return false
        }
        // Prefer physical key matching so the shortcut works across keyboard layouts/IMEs.
        if event.keyCode == UInt16(kVK_ANSI_C) {
            return true
        }
        return event.charactersIgnoringModifiers?.lowercased() == "c"
    }
}

@MainActor
final class CapsuleWindowController {
    private let state: RecordingState
    private let panel: CapsulePanel

    init(state: RecordingState) {
        self.state = state

        let hosting = NSHostingController(rootView: CapsuleLayerRootView(state: state))
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

        panel.onEscDown = { [weak self] in
            self?.state.handleCancel()
        }
        panel.onCopyDown = { [weak self] in
            self?.state.copyVoiceCommandResultLayerText()
        }

        state.onWillDeliverText = { [weak panel] in
            panel?.resignKey()
        }

        // Use Observation framework for @Observable state
        startObserving()

        // Initial visibility update
        updateVisibility()
    }

    private func startObserving() {
        // withObservationTracking is one-shot, need to recursively re-register
        func observe() {
            _ = withObservationTracking {
                _ = state.capsuleState
                _ = state.voiceCommandResultLayer
            } onChange: { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.updateVisibility()
                    observe() // Re-register for next change
                }
            }
        }
        observe()
    }

    private func updateVisibility() {
        let isResultLayerVisible = state.voiceCommandResultLayer != nil
        let isCapsuleVisible = !isCapsuleHidden(state.capsuleState)

        if !isResultLayerVisible && !isCapsuleVisible {
            panel.orderOut(nil)
            return
        }

        panel.captureNonEscKeyDown = !isResultLayerVisible
        panel.ignoresMouseEvents = !isResultLayerVisible

        // Defer positioning to next run loop to allow SwiftUI layout to complete
        DispatchQueue.main.async { [weak self] in
            self?.positionWindow()
        }
        panel.alphaValue = 1.0

        if shouldPanelBeKey(capsuleState: state.capsuleState, isResultLayerVisible: isResultLayerVisible) {
            panel.orderFrontRegardless()
            panel.makeKey()
        } else {
            panel.resignKey()
            panel.orderFrontRegardless()
        }
    }

    private func isCapsuleHidden(_ state: CapsuleState) -> Bool {
        if case .hidden = state {
            return true
        }
        return false
    }

    private func shouldPanelBeKey(capsuleState: CapsuleState, isResultLayerVisible: Bool) -> Bool {
        if isResultLayerVisible {
            return true
        }
        switch capsuleState {
        case .recording, .transcribing, .polishing, .processingCommand:
            return true
        default:
            return false
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        let isResultLayerVisible = state.voiceCommandResultLayer != nil
        let contentSize = panel.contentView?.fittingSize ?? CGSize(
            width: CapsuleView.minCapsuleWidth,
            height: CapsuleView.capsuleHeight
        )
        let width: CGFloat
        let height: CGFloat

        if isResultLayerVisible {
            width = max(contentSize.width, VoiceCommandResultLayerView.layerWidth)
            height = max(contentSize.height, VoiceCommandResultLayerView.layerHeight)
        } else {
            width = max(contentSize.width, CapsuleView.minCapsuleWidth)
            height = CapsuleView.capsuleHeight + 14 // padding for window chrome
        }

        let x = frame.midX - width / 2
        let y = frame.minY + 24
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
