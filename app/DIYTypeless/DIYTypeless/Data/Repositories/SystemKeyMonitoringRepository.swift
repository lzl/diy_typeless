import AppKit

final class SystemKeyMonitoringRepository: KeyMonitoringRepository {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRunning = false
    private var isFnDown = false

    func start() -> Bool {
        if isRunning {
            return true
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
            return event
        }

        guard globalMonitor != nil || localMonitor != nil else {
            return false
        }

        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        globalMonitor = nil
        localMonitor = nil
        isRunning = false
        isFnDown = false
    }

    private func handle(event: NSEvent) {
        let isDown = event.modifierFlags.contains(.function)
        if isDown && !isFnDown {
            isFnDown = true
            onFnDown?()
        } else if !isDown && isFnDown {
            isFnDown = false
            onFnUp?()
        }
    }
}
