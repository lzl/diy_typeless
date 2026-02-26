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

    // MARK: - Non-Empty Input Validation

    @Test("Non-empty input passes validation (no emptyInput error)")
    func testNonEmptyInput_PassesValidation() async throws {
        // Given: Use case with valid text
        let useCase = PolishTextUseCaseImpl()

        // When: Call with non-empty text
        // Then: Should NOT throw emptyInput error (FFI may fail but validation passes)
        do {
            _ = try await useCase.execute(rawText: "hello", apiKey: "test-key", context: nil)
        } catch {
            // FFI error is expected, but emptyInput should NOT be thrown
            if case PolishingError.emptyInput = error {
                Issue.record("Should not throw emptyInput for non-empty text")
            }
            // Other errors are acceptable (FFI needs real API key)
        }
    }

    // MARK: - Context Parameter

    @Test("Context parameter is passed through validation")
    func testContextParameter_PassesValidation() async throws {
        // Given: Use case with context
        let useCase = PolishTextUseCaseImpl()
        let context = "TestApp"

        // When: Call with context
        // Then: Should not throw emptyInput
        do {
            _ = try await useCase.execute(
                rawText: "test",
                apiKey: "test-key",
                context: context
            )
        } catch {
            if case PolishingError.emptyInput = error {
                Issue.record("Should not throw emptyInput when context provided")
            }
        }
    }
}