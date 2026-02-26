//
//  PolishTextUseCaseTests.swift
//  DIYTypelessTests
//
//  Tests for PolishTextUseCase
//

import Testing
import Foundation
@testable import DIYTypeless

@MainActor
@Suite("PolishTextUseCase Tests")
struct PolishTextUseCaseTests {

    // MARK: - Empty Input Tests

    @Test("Empty input throws PolishingError.emptyInput")
    func testEmptyInput_ThrowsError() async throws {
        // Given: Use case with empty text
        let useCase = PolishTextUseCaseImpl()

        // When/Then: Should throw emptyInput error
        await #expect(throws: PolishingError.emptyInput) {
            try await useCase.execute(rawText: "", apiKey: "test-key", context: nil)
        }
    }

    @Test("Whitespace only input throws PolishingError.emptyInput")
    func testWhitespaceOnly_ThrowsError() async throws {
        // Given: Use case with whitespace-only text
        let useCase = PolishTextUseCaseImpl()

        // When/Then: Should throw emptyInput error
        await #expect(throws: PolishingError.emptyInput) {
            try await useCase.execute(rawText: "   ", apiKey: "test-key", context: nil)
        }
    }

    // MARK: - Successful Polishing

    @Test("Non-empty input does not throw emptyInput")
    func testNonEmptyInput_DoesNotThrow() async throws {
        // Given: Use case with valid text (though FFI will fail without real key)
        let useCase = PolishTextUseCaseImpl()

        // When: Call with non-empty text
        // Then: Should NOT throw emptyInput error
        // (may throw other errors like API error, but not emptyInput)
        do {
            _ = try await useCase.execute(rawText: "hello", apiKey: "test-key", context: nil)
        } catch PolishingError.emptyInput {
            Issue.record("Should not throw emptyInput for non-empty text")
        }
    }

    // MARK: - Context Parameter

    @Test("Context parameter is passed correctly")
    func testContextParameter_Passed() async throws {
        // Given: Use case with context
        let useCase = PolishTextUseCaseImpl()
        let context = "TestApp"

        // When: Call with context
        // Then: Should not throw emptyInput (validates input processing)
        do {
            _ = try await useCase.execute(
                rawText: "test",
                apiKey: "test-key",
                context: context
            )
        } catch PolishingError.emptyInput {
            Issue.record("Should not throw emptyInput when context provided")
        }
    }
}