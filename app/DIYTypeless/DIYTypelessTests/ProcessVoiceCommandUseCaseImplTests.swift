import XCTest
#if canImport(DIYTypeless)
@testable import DIYTypeless
#elseif canImport(DIYTypelessHeadlessCore)
@testable import DIYTypelessHeadlessCore
#endif

final class ProcessVoiceCommandUseCaseImplTests: XCTestCase {
    func testExecute_success_buildsPromptAndReturnsReplaceSelectionAction() async throws {
        let repository = MockLLMRepository()
        repository.response = "updated text"
        let sut = ProcessVoiceCommandUseCaseImpl(llmRepository: repository)

        let result = try await sut.execute(
            transcription: "make it concise",
            selectedText: "This sentence is too long.",
            geminiKey: "gem-key",
            cancellationToken: nil
        )

        XCTAssertEqual(result.processedText, "updated text")
        XCTAssertEqual(result.action, .replaceSelection)
        XCTAssertEqual(repository.receivedAPIKey, "gem-key")
        XCTAssertEqual(repository.receivedTemperature, 0.3)

        let prompt = repository.receivedPrompt ?? ""
        XCTAssertTrue(prompt.contains("User says: make it concise"))
        XCTAssertTrue(prompt.contains("This sentence is too long."))
        XCTAssertTrue(prompt.contains("Only return the processed text"))
    }

    func testExecute_whenTokenAlreadyCancelled_throwsCancellationWithoutRepositoryCall() async {
        let repository = MockLLMRepository()
        let sut = ProcessVoiceCommandUseCaseImpl(llmRepository: repository)
        let token = FakeCancellationToken(isCancelled: true)

        do {
            _ = try await sut.execute(
                transcription: "do something",
                selectedText: "text",
                geminiKey: "key",
                cancellationToken: token
            )
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            XCTAssertEqual(repository.generateCallCount, 0)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testExecute_whenCoreApi401_mapsToInvalidApiKey() async {
        let repository = MockLLMRepository()
        repository.error = CoreError.Api("401 unauthorized")
        let sut = ProcessVoiceCommandUseCaseImpl(llmRepository: repository)

        do {
            _ = try await sut.execute(
                transcription: "fix",
                selectedText: "text",
                geminiKey: "key",
                cancellationToken: nil
            )
            XCTFail("Expected UserFacingError.invalidAPIKey")
        } catch let error as UserFacingError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("Expected UserFacingError, got \(error)")
        }
    }

    func testExecute_whenCoreHttpError_mapsToNetworkError() async {
        let repository = MockLLMRepository()
        repository.error = CoreError.Http("timeout")
        let sut = ProcessVoiceCommandUseCaseImpl(llmRepository: repository)

        do {
            _ = try await sut.execute(
                transcription: "fix",
                selectedText: "text",
                geminiKey: "key",
                cancellationToken: nil
            )
            XCTFail("Expected UserFacingError.networkError")
        } catch let error as UserFacingError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Expected UserFacingError, got \(error)")
        }
    }

    func testExecute_whenCoreCancelled_throwsCancellationError() async {
        let repository = MockLLMRepository()
        repository.error = CoreError.Cancelled
        let sut = ProcessVoiceCommandUseCaseImpl(llmRepository: repository)

        do {
            _ = try await sut.execute(
                transcription: "fix",
                selectedText: "text",
                geminiKey: "key",
                cancellationToken: nil
            )
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
