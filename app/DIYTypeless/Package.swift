// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DIYTypelessHeadlessCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DIYTypelessHeadlessCore",
            targets: ["DIYTypelessHeadlessCore"]
        )
    ],
    targets: [
        .target(
            name: "DIYTypelessHeadlessCore",
            path: "DIYTypeless",
            sources: [
                "Domain/Entities/ApiProvider.swift",
                "Domain/Entities/DomainAudioData.swift",
                "Domain/Entities/OutputResult.swift",
                "Domain/Entities/PermissionStatus.swift",
                "Domain/Entities/SelectedTextContext.swift",
                "Domain/Entities/TranscriptionEntities.swift",
                "Domain/Entities/ValidationState.swift",
                "Domain/Entities/VoiceCommandResult.swift",
                "Domain/Errors/CoreErrorMapper.swift",
                "Domain/Errors/UserFacingError.swift",
                "Domain/Errors/ValidationError.swift",
                "Domain/Protocols/PrefetchScheduler.swift",
                "Domain/Repositories/ApiKeyRepository.swift",
                "Domain/Repositories/ApiKeyValidationRepository.swift",
                "Domain/Repositories/AppContextRepository.swift",
                "Domain/Repositories/ExternalLinkRepository.swift",
                "Domain/Repositories/KeyMonitoringRepository.swift",
                "Domain/Repositories/LLMRepository.swift",
                "Domain/Repositories/PermissionRepository.swift",
                "Domain/Repositories/SelectedTextRepository.swift",
                "Domain/Repositories/TextOutputRepository.swift",
                "Domain/UseCases/GetSelectedTextUseCase.swift",
                "Domain/UseCases/PolishTextUseCase.swift",
                "Domain/UseCases/ProcessVoiceCommandUseCase.swift",
                "Domain/UseCases/RecordingControlUseCase.swift",
                "Domain/UseCases/StopRecordingUseCase.swift",
                "Domain/UseCases/TranscribeAudioUseCase.swift",
                "Domain/UseCases/TranscriptionUseCase.swift",
                "Domain/UseCases/ValidateApiKeyUseCase.swift",
                "Data/UseCases/ProcessVoiceCommandUseCaseImpl.swift",
                "Infrastructure/Headless/SwiftPackageShims.swift",
                "Infrastructure/Scheduling/RealPrefetchScheduler.swift",
                "State/OnboardingState.swift",
                "State/RecordingState.swift",
                "State/VoiceCommandResultLayerState.swift"
            ]
        ),
        .testTarget(
            name: "DIYTypelessHeadlessCoreTests",
            dependencies: ["DIYTypelessHeadlessCore"],
            path: "DIYTypelessTests",
            sources: [
                "CoreErrorMapperTests.swift",
                "OnboardingStateTests.swift",
                "ProcessVoiceCommandUseCaseImplTests.swift",
                "RecordingStateTests.swift",
                "TestDoubles.swift",
                "TranscriptionUseCaseTests.swift"
            ]
        )
    ]
)
