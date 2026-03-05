import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

final class ValidateApiKeyUseCaseTests: XCTestCase {
    func testExecute_whenProviderIsGroq_callsGroqRepositoryOnly() async throws {
        let groqRepository = SpyApiKeyValidationRepository()
        let geminiRepository = SpyApiKeyValidationRepository()
        let sut = ValidateApiKeyUseCase(
            groqRepository: groqRepository,
            geminiRepository: geminiRepository
        )

        try await sut.execute(key: "groq-key", for: .groq)
        let groqKeys = await groqRepository.receivedKeys()
        let geminiKeys = await geminiRepository.receivedKeys()

        XCTAssertEqual(groqKeys, ["groq-key"])
        XCTAssertEqual(geminiKeys, [])
    }

    func testExecute_whenProviderIsGemini_callsGeminiRepositoryOnly() async throws {
        let groqRepository = SpyApiKeyValidationRepository()
        let geminiRepository = SpyApiKeyValidationRepository()
        let sut = ValidateApiKeyUseCase(
            groqRepository: groqRepository,
            geminiRepository: geminiRepository
        )

        try await sut.execute(key: "gemini-key", for: .gemini)
        let groqKeys = await groqRepository.receivedKeys()
        let geminiKeys = await geminiRepository.receivedKeys()

        XCTAssertEqual(groqKeys, [])
        XCTAssertEqual(geminiKeys, ["gemini-key"])
    }

    func testExecute_whenRepositoryThrows_propagatesValidationError() async {
        let expected = ValidationError(message: "invalid key")
        let groqRepository = SpyApiKeyValidationRepository(error: expected)
        let geminiRepository = SpyApiKeyValidationRepository()
        let sut = ValidateApiKeyUseCase(
            groqRepository: groqRepository,
            geminiRepository: geminiRepository
        )

        do {
            try await sut.execute(key: "bad", for: .groq)
            XCTFail("Expected ValidationError")
        } catch let error as ValidationError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Expected ValidationError, got \(error)")
        }
    }
}

private actor SpyApiKeyValidationRepository: ApiKeyValidationRepository {
    private var keys: [String] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func validate(key: String) async throws {
        keys.append(key)
        if let error {
            throw error
        }
    }

    func receivedKeys() -> [String] {
        keys
    }
}
