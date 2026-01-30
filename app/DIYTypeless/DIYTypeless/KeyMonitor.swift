import AppKit

final class KeyMonitor {
    var onRightOptionDown: (() -> Void)?
    var onRightOptionUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var isRightOptionDown = false

    private let rightOptionKeyCode: Int64 = 61

    func start() -> Bool {
        if isRunning {
            return true
        }

        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(event: event, type: type)
            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
        isRightOptionDown = false
    }

    private func handle(event: CGEvent, type: CGEventType) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode != rightOptionKeyCode {
            return
        }

        switch type {
        case .flagsChanged:
            let isDown = event.flags.contains(.maskAlternate)
            if isDown && !isRightOptionDown {
                isRightOptionDown = true
                onRightOptionDown?()
            } else if !isDown && isRightOptionDown {
                isRightOptionDown = false
                onRightOptionUp?()
            }
        case .keyDown:
            if !isRightOptionDown {
                isRightOptionDown = true
                onRightOptionDown?()
            }
        case .keyUp:
            if isRightOptionDown {
                isRightOptionDown = false
                onRightOptionUp?()
            }
        default:
            break
        }
    }
}

