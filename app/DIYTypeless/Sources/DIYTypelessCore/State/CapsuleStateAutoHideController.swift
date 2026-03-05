import Foundation

@MainActor
public final class CapsuleStateAutoHideController {
    public typealias ScheduleWork = (_ delay: TimeInterval, _ workItem: DispatchWorkItem) -> Void

    private var pendingWorkItem: DispatchWorkItem?
    private let scheduleWork: ScheduleWork

    public init(
        scheduleWork: @escaping ScheduleWork = { delay, workItem in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    ) {
        self.scheduleWork = scheduleWork
    }

    public func schedule(
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
        scheduleWork(delay, workItem)
    }

    public func cancel() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
}
