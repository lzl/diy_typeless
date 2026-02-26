# Data Layer

This layer contains **concrete implementations** of the protocols defined in Domain. It bridges Domain logic with external systems (Keychain, Network, Accessibility APIs).

## Purpose

- Implement Domain protocols with real-world functionality
- Handle infrastructure concerns (Keychain, network, system APIs)
- Keep external dependencies isolated from business logic

## Subdirectories

### Repositories/
Concrete implementations of Domain repository protocols.

| Implementation | Protocol | External Dependency |
|----------------|----------|---------------------|
| `KeychainApiKeyRepository` | ApiKeyRepository | macOS Keychain |
| `GroqApiKeyValidationRepository` | ApiKeyValidationRepository | Groq API |
| `GeminiApiKeyValidationRepository` | ApiKeyValidationRepository | Gemini API |
| `GeminiLLMRepository` | LLMRepository | Gemini API |
| `DefaultAppContextRepository` | AppContextRepository | NSWorkspace |
| `AccessibilitySelectedTextRepository` | SelectedTextRepository | Accessibility API |
| `SystemKeyMonitoringRepository` | KeyMonitoringRepository | NSEvent |
| `SystemPermissionRepository` | PermissionRepository | AXIsProcessTrusted |
| `SystemTextOutputRepository` | TextOutputRepository | CGEvent |
| `NSWorkspaceExternalLinkRepository` | ExternalLinkRepository | NSWorkspace |

### UseCases/
Concrete implementations of Domain use case protocols.

| Implementation | Protocol | Dependencies |
|----------------|----------|--------------|
| `PolishTextUseCaseImpl` | PolishTextUseCase | LLMRepository |
| `RecordingControlUseCaseImpl` | RecordingControlUseCase | (Audio capture) |
| `StopRecordingUseCaseImpl` | StopRecordingUseCase | (Audio capture) |
| `TranscribeAudioUseCaseImpl` | TranscribeAudioUseCase | (Core FFI) |

## Key Principles

1. **Implement Domain protocols** - Never define new protocols here
2. **External dependencies** - Keychain, Network, System APIs
3. **Async/await** - Use Swift concurrency for async operations
4. **FFI bridging** - Audio transcription uses Rust core via UniFFI

## Usage

When AI needs to modify how something works:
1. Find the Domain protocol first to understand the interface
2. Then look here for the implementation details
3. Check FFI bridge (Infrastructure/) for Rust core integration

## Important Notes

- Audio transcription is handled by Rust core via FFI
- Network calls use URLSession for LLM APIs
- Keychain API uses Security framework