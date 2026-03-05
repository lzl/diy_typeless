import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

@MainActor
final class CapsuleStateAutoHideControllerTests: XCTestCase {
    func testSchedule_whenStaleWorkFires_doesNotHideLatestState() {
        let scheduler = ManualAutoHideScheduler()
        let sut = CapsuleStateAutoHideController(scheduleWork: scheduler.schedule)
        var state: CapsuleState = .error(.invalidAPIKey)

        sut.schedule(
            after: 2.0,
            expectedState: .error(.invalidAPIKey),
            currentState: { state },
            onHide: { state = .hidden }
        )

        state = .error(.networkError)
        sut.schedule(
            after: 2.0,
            expectedState: .error(.networkError),
            currentState: { state },
            onHide: { state = .hidden }
        )

        scheduler.runNext()
        XCTAssertEqual(state, .error(.networkError))

        scheduler.runNext()
        XCTAssertEqual(state, .hidden)
    }

    func testCancel_whenPendingWorkExists_preventsHide() {
        let scheduler = ManualAutoHideScheduler()
        let sut = CapsuleStateAutoHideController(scheduleWork: scheduler.schedule)
        var state: CapsuleState = .canceled

        sut.schedule(
            after: 1.0,
            expectedState: .canceled,
            currentState: { state },
            onHide: { state = .hidden }
        )
        sut.cancel()

        scheduler.runNext()
        XCTAssertEqual(state, .canceled)
    }
}

@MainActor
private final class ManualAutoHideScheduler {
    private var workItems: [DispatchWorkItem] = []

    func schedule(delay: TimeInterval, workItem: DispatchWorkItem) {
        _ = delay
        workItems.append(workItem)
    }

    func runNext() {
        guard !workItems.isEmpty else { return }
        let workItem = workItems.removeFirst()
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
