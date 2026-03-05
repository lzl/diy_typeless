import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

final class CapsuleStateTransitionGuardTests: XCTestCase {
    func testCanTransition_validPaths_returnsTrue() {
        let sut = CapsuleStateTransitionGuard()

        XCTAssertTrue(sut.canTransition(from: .hidden, to: .recording))
        XCTAssertTrue(sut.canTransition(from: .recording, to: .transcribing(progress: 0)))
        XCTAssertTrue(sut.canTransition(from: .transcribing(progress: 0), to: .polishing(progress: 0)))
        XCTAssertTrue(sut.canTransition(from: .polishing(progress: 0), to: .done(.copied)))
        XCTAssertTrue(sut.canTransition(from: .done(.copied), to: .hidden))
        XCTAssertTrue(sut.canTransition(from: .error(.invalidAPIKey), to: .recording))
    }

    func testCanTransition_invalidJumps_returnsFalse() {
        let sut = CapsuleStateTransitionGuard()

        XCTAssertFalse(sut.canTransition(from: .hidden, to: .polishing(progress: 0)))
        XCTAssertFalse(sut.canTransition(from: .recording, to: .done(.pasted)))
        XCTAssertFalse(sut.canTransition(from: .processingCommand("cmd", progress: 0), to: .transcribing(progress: 0)))
        XCTAssertFalse(sut.canTransition(from: .done(.pasted), to: .polishing(progress: 0)))
    }

    func testCanTransition_samePhaseTransition_returnsTrue() {
        let sut = CapsuleStateTransitionGuard()

        XCTAssertTrue(sut.canTransition(from: .error(.invalidAPIKey), to: .error(.networkError)))
        XCTAssertTrue(sut.canTransition(from: .hidden, to: .hidden))
    }
}
