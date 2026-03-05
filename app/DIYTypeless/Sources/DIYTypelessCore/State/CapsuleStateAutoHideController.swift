import Foundation

@MainActor
final class CapsuleStateAutoHideController {
    private var pendingWorkItem: DispatchWorkItem?

    func schedule(
        after delay: TimeInterval,
        expectedState: CapsuleState,
        currentState: @escaping () -> CapsuleState,
        onHide: @escaping () -> Void
    ) {
        cancel()

        let workItem = DispatchWorkItem {
            guard currentState() == expectedState else { return }
            onHide()
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancel() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
}
