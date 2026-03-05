import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

final class GetSelectedTextUseCaseTests: XCTestCase {
    func testExecute_returnsRepositoryContextAndDelegatesSingleCall() async {
        let repository = SpySelectedTextRepository(
            result: SelectedTextContext(
                text: "selected text",
                isEditable: true,
                isSecure: false,
                applicationName: "Notes"
            )
        )
        let sut = GetSelectedTextUseCase(repository: repository)

        let context = await sut.execute()
        let callCount = await repository.callCount()

        XCTAssertEqual(context.text, "selected text")
        XCTAssertEqual(context.isEditable, true)
        XCTAssertEqual(context.isSecure, false)
        XCTAssertEqual(context.applicationName, "Notes")
        XCTAssertEqual(callCount, 1)
    }
}

private actor SpySelectedTextRepository: SelectedTextRepository {
    private let result: SelectedTextContext
    private var calls = 0

    init(result: SelectedTextContext) {
        self.result = result
    }

    func getSelectedText() async -> SelectedTextContext {
        calls += 1
        return result
    }

    func callCount() -> Int {
        calls
    }
}
