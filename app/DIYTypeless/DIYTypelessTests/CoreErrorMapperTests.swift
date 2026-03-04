import XCTest
#if canImport(DIYTypeless)
@testable import DIYTypeless
#elseif canImport(DIYTypelessHeadlessCore)
@testable import DIYTypelessHeadlessCore
#endif

final class CoreErrorMapperTests: XCTestCase {
    func testApiCategory_mapsCommonStatusCodesToExpectedUserErrors() {
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .api, message: "401 unauthorized"),
            .invalidAPIKey
        )
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .api, message: "403 forbidden"),
            .regionBlocked
        )
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .api, message: "429 too many requests"),
            .rateLimited
        )
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .api, message: "503 service unavailable"),
            .serviceUnavailable
        )
    }

    func testApiCategory_withUnrecognizedMessage_returnsUnknownPreservingMessage() {
        let message = "unexpected provider response"
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .api, message: message),
            .unknown(message)
        )
    }

    func testNetworkCategory_alwaysMapsToNetworkError() {
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .network, message: "connection lost"),
            .networkError
        )
    }

    func testUnknownCategory_returnsUnknownWithOriginalMessage() {
        let message = "some internal failure"
        XCTAssertEqual(
            CoreErrorMapper.toUserFacingError(category: .unknown, message: message),
            .unknown(message)
        )
    }
}
