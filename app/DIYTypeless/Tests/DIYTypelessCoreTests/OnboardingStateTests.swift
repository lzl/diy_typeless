import XCTest
#if canImport(DIYTypeless)
@testable import DIYTypeless
#elseif canImport(DIYTypelessCore)
@testable import DIYTypelessCore
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

        let (sut, dependencies) = makeSUT(
            permissionRepository: permissionRepository,
            apiKeyRepository: apiKeyRepository,
            validateApiKeyUseCase: validateUseCase
        )

        await waitUntil { dependencies.validateApiKeyUseCase.executeCalls.count == 2 }

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
