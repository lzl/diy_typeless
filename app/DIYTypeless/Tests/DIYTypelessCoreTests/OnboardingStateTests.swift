import XCTest
#if canImport(DIYTypelessCore)
import DIYTypelessCore
#elseif canImport(DIYTypeless)
@testable import DIYTypeless
#endif

@MainActor
final class OnboardingStateTests: XCTestCase {
    private let hasCompletedWelcomeKey = "hasCompletedWelcome"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: hasCompletedWelcomeKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: hasCompletedWelcomeKey)
        super.tearDown()
    }

    func testInit_whenWelcomeCompletedAndPrerequisitesMet_startsAtCompletionStep() async {
        UserDefaults.standard.set(true, forKey: hasCompletedWelcomeKey)

        let permissionRepository = MockPermissionRepository(
            currentStatus: PermissionStatus(accessibility: true, microphone: true)
        )
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "groq-key"
        apiKeyRepository.keys[.gemini] = "gemini-key"
        let validateUseCase = MockValidateApiKeyUseCase()

        let (sut, _) = makeSUT(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            validateApiKeyUseCase: validateUseCase
        )

        XCTAssertEqual(sut.step, .completion)
        XCTAssertEqual(sut.groqValidation, .success)
        XCTAssertEqual(sut.geminiValidation, .success)
    }

    func testValidateGroqKey_whenInputIsEmpty_setsFailureMessage() async {
        let (sut, _) = makeSUT()
        sut.groqKey = "  \n  "

        sut.validateGroqKey()
        await Task.yield()

        XCTAssertEqual(sut.groqValidation, .failure("Enter your Groq API key to continue."))
    }

    func testValidateGroqKey_success_savesTrimmedKeyAndMarksSuccess() async {
        let apiKeyRepository = MockApiKeyRepository()
        let validateUseCase = MockValidateApiKeyUseCase()
        let (sut, dependencies) = makeSUT(
            apiKeyRepository: apiKeyRepository,
            validateApiKeyUseCase: validateUseCase
        )

        sut.groqKey = "  gsk_12345  "
        sut.validateGroqKey()

        await waitUntil { sut.groqValidation == .success }

        XCTAssertEqual(dependencies.validateApiKeyUseCase.executeCalls.count, 1)
        XCTAssertEqual(dependencies.validateApiKeyUseCase.executeCalls.first?.key, "gsk_12345")
        XCTAssertEqual(dependencies.apiKeyRepository.saveCalls.first?.provider, .groq)
        XCTAssertEqual(dependencies.apiKeyRepository.saveCalls.first?.key, "gsk_12345")
    }

    func testValidateGeminiKey_withValidationError_surfacesDomainMessage() async {
        let validateUseCase = MockValidateApiKeyUseCase()
        validateUseCase.behaviorByProvider[.gemini] = .failure(
            ValidationError(message: "Gemini key rejected")
        )

        let (sut, _) = makeSUT(validateApiKeyUseCase: validateUseCase)
        sut.geminiKey = "bad-key"

        sut.validateGeminiKey()

        await waitUntil {
            if case .failure = sut.geminiValidation {
                return true
            }
            return false
        }

        XCTAssertEqual(sut.geminiValidation, .failure("Gemini key rejected"))
    }

    func testEditingKey_resetsValidationStateToIdle() async {
        let (sut, _) = makeSUT()
        sut.groqKey = "first"
        sut.validateGroqKey()
        await waitUntil { sut.groqValidation == .success }

        sut.groqKey = "updated"

        XCTAssertEqual(sut.groqValidation, .idle)
    }

    func testRefresh_whenEarlierRevalidationCompletesLast_doesNotOverrideLatestGroqValidation() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "old-groq"
        apiKeyRepository.keys[.gemini] = ""

        let validateUseCase = ControlledValidateApiKeyUseCase()
        let sut = OnboardingState(
            permissionRepository: MockPermissionRepository(),
            apiKeyRepository: apiKeyRepository,
            externalLinkRepository: MockExternalLinkRepository(),
            validateApiKeyUseCase: validateUseCase
        )

        await waitUntil { validateUseCase.callCount(for: .groq) == 1 }

        apiKeyRepository.keys[.groq] = "new-groq"
        sut.refresh()
        await waitUntil { validateUseCase.callCount(for: .groq) == 2 }

        validateUseCase.resolveCall(
            provider: .groq,
            at: 1,
            result: .success(())
        )
        await waitUntil { sut.groqValidation == ValidationState.success }

        validateUseCase.resolveCall(
            provider: .groq,
            at: 0,
            result: .failure(ValidationError(message: "stale failure"))
        )
        await Task.yield()

        XCTAssertEqual(sut.groqValidation, ValidationState.success)
    }

    func testRefresh_whenSameGroqKeyRevalidationCompletesOutOfOrder_doesNotApplyStaleFailure() async {
        let apiKeyRepository = MockApiKeyRepository()
        apiKeyRepository.keys[.groq] = "same-groq"
        apiKeyRepository.keys[.gemini] = ""

        let validateUseCase = ControlledValidateApiKeyUseCase()
        let sut = OnboardingState(
            permissionRepository: MockPermissionRepository(),
            apiKeyRepository: apiKeyRepository,
            externalLinkRepository: MockExternalLinkRepository(),
            validateApiKeyUseCase: validateUseCase
        )

        await waitUntil { validateUseCase.callCount(for: .groq) == 1 }

        sut.refresh()
        await waitUntil { validateUseCase.callCount(for: .groq) == 2 }

        validateUseCase.resolveCall(
            provider: .groq,
            at: 1,
            result: .success(())
        )
        await waitUntil { sut.groqValidation == ValidationState.success }

        validateUseCase.resolveCall(
            provider: .groq,
            at: 0,
            result: .failure(ValidationError(message: "stale same-key failure"))
        )
        await Task.yield()

        XCTAssertEqual(sut.groqValidation, ValidationState.success)
    }

    func testValidateGroqKey_whenKeyChangesDuringValidation_keepsIdleForNewValue() async {
        let validateUseCase = ControlledValidateApiKeyUseCase()
        let sut = OnboardingState(
            permissionRepository: MockPermissionRepository(),
            apiKeyRepository: MockApiKeyRepository(),
            externalLinkRepository: MockExternalLinkRepository(),
            validateApiKeyUseCase: validateUseCase
        )

        sut.groqKey = "old-key"
        sut.validateGroqKey()
        await waitUntil { validateUseCase.callCount(for: .groq) == 1 }

        sut.groqKey = "new-key"
        XCTAssertEqual(sut.groqValidation, .idle)

        validateUseCase.resolveCall(
            provider: .groq,
            at: 0,
            result: .success(())
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(sut.groqValidation, .idle)
    }

    private func makeSUT(
        permissionRepository: MockPermissionRepository = MockPermissionRepository(),
        apiKeyRepository: MockApiKeyRepository = MockApiKeyRepository(),
        externalLinkRepository: MockExternalLinkRepository = MockExternalLinkRepository(),
        validateApiKeyUseCase: MockValidateApiKeyUseCase = MockValidateApiKeyUseCase()
    ) -> (sut: OnboardingState, dependencies: Dependencies) {
        let sut = OnboardingState(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            externalLinkRepository: externalLinkRepository,
            validateApiKeyUseCase: validateApiKeyUseCase
        )

        let dependencies = Dependencies(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            externalLinkRepository: externalLinkRepository,
            validateApiKeyUseCase: validateApiKeyUseCase
        )

        return (sut, dependencies)
    }

    struct Dependencies {
        let permissionRepository: MockPermissionRepository
        let apiKeyRepository: MockApiKeyRepository
        let externalLinkRepository: MockExternalLinkRepository
        let validateApiKeyUseCase: MockValidateApiKeyUseCase
    }
}

@MainActor
private final class ControlledValidateApiKeyUseCase: ValidateApiKeyUseCaseProtocol {
    private var pendingContinuationsByProvider: [ApiProvider: [CheckedContinuation<Void, Error>]] = [:]
    private var callsByProvider: [ApiProvider: [String]] = [:]

    func execute(key: String, for provider: ApiProvider) async throws {
        callsByProvider[provider, default: []].append(key)
        try await withCheckedThrowingContinuation { continuation in
            pendingContinuationsByProvider[provider, default: []].append(continuation)
        }
    }

    func callCount(for provider: ApiProvider) -> Int {
        callsByProvider[provider, default: []].count
    }

    func resolveCall(provider: ApiProvider, at index: Int, result: Result<Void, Error>) {
        guard var providerContinuations = pendingContinuationsByProvider[provider] else {
            XCTFail("No pending continuations for provider \(provider)")
            return
        }
        guard providerContinuations.indices.contains(index) else {
            XCTFail("No continuation at index \(index) for provider \(provider)")
            return
        }

        let continuation = providerContinuations.remove(at: index)
        pendingContinuationsByProvider[provider] = providerContinuations

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
