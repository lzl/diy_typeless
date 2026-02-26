//
//  ValidateApiKeyUseCaseTests.swift
//  DIYTypelessTests
//
//  Tests for ValidateApiKeyUseCase
//

import Testing
import Foundation
@testable import DIYTypeless

// MARK: - Mock Repository

@MainActor
final class MockApiKeyValidationRepository: ApiKeyValidationRepository {
    var shouldThrow: Error?
    var validateCallCount = 0
    var lastValidatedKey: String?

    func validate(key: String) async throws {
        validateCallCount += 1
        lastValidatedKey = key
        if let error = shouldThrow {
            throw error
        }
    }
}

// MARK: - Tests

@MainActor
@Suite("ValidateApiKeyUseCase Tests")
struct ValidateApiKeyUseCaseTests {

    // MARK: - Groq Provider Tests

    @Test("Groq key is validated with GroqRepository")
    func testGroqKey_UsesGroqRepository() async throws {
        // Given: Use case with mock repository
        let mockGroqRepo = MockApiKeyValidationRepository()
        let useCase = ValidateApiKeyUseCase(
            groqRepository: mockGroqRepo,
            geminiRepository: MockApiKeyValidationRepository()
        )

        // When: Validate Groq key
        try await useCase.execute(key: "groq-test-key", for: .groq)

        // Then: Groq repository should be called
        #expect(mockGroqRepo.validateCallCount == 1)
        #expect(mockGroqRepo.lastValidatedKey == "groq-test-key")
    }

    @Test("Groq repository error is propagated")
    func testGroqKey_ErrorPropagated() async throws {
        // Given: Use case with mock that throws
        let mockGroqRepo = MockApiKeyValidationRepository()
        mockGroqRepo.shouldThrow = ValidationError.invalidKey("Invalid Groq key")

        let useCase = ValidateApiKeyUseCase(
            groqRepository: mockGroqRepo,
            geminiRepository: MockApiKeyValidationRepository()
        )

        // When/Then: Error should propagate
        await #expect(throws: ValidationError.invalidKey("Invalid Groq key")) {
            try await useCase.execute(key: "bad-key", for: .groq)
        }
    }

    // MARK: - Gemini Provider Tests

    @Test("Gemini key is validated with GeminiRepository")
    func testGeminiKey_UsesGeminiRepository() async throws {
        // Given: Use case with mock repository
        let mockGeminiRepo = MockApiKeyValidationRepository()
        let useCase = ValidateApiKeyUseCase(
            groqRepository: MockApiKeyValidationRepository(),
            geminiRepository: mockGeminiRepo
        )

        // When: Validate Gemini key
        try await useCase.execute(key: "gemini-test-key", for: .gemini)

        // Then: Gemini repository should be called
        #expect(mockGeminiRepo.validateCallCount == 1)
        #expect(mockGeminiRepo.lastValidatedKey == "gemini-test-key")
    }

    @Test("Gemini repository error is propagated")
    func testGeminiKey_ErrorPropagated() async throws {
        // Given: Use case with mock that throws
        let mockGeminiRepo = MockApiKeyValidationRepository()
        mockGeminiRepo.shouldThrow = ValidationError.invalidKey("Invalid Gemini key")

        let useCase = ValidateApiKeyUseCase(
            groqRepository: MockApiKeyValidationRepository(),
            geminiRepository: mockGeminiRepo
        )

        // When/Then: Error should propagate
        await #expect(throws: ValidationError.invalidKey("Invalid Gemini key")) {
            try await useCase.execute(key: "bad-key", for: .gemini)
        }
    }

    // MARK: - Provider Routing Tests

    @Test("Correct repository is used for each provider")
    func testProviderRouting() async throws {
        // Given: Mocks for both providers
        let mockGroqRepo = MockApiKeyValidationRepository()
        let mockGeminiRepo = MockApiKeyValidationRepository()

        let useCase = ValidateApiKeyUseCase(
            groqRepository: mockGroqRepo,
            geminiRepository: mockGeminiRepo
        )

        // When: Validate both providers
        try await useCase.execute(key: "groq-key", for: .groq)
        try await useCase.execute(key: "gemini-key", for: .gemini)

        // Then: Each repository called exactly once
        #expect(mockGroqRepo.validateCallCount == 1)
        #expect(mockGeminiRepo.validateCallCount == 1)
    }
}