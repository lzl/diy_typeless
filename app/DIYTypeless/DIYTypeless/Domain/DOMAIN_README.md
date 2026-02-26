# Domain Layer

This layer contains pure Swift business logic with **no external dependencies**. All types here are protocols (interfaces) that define what the application can do, not how it does it.

## Purpose

- Define business rules without coupling to UI or infrastructure
- Provide simple interfaces (protocols) for the Data layer to implement
- Enable testability through dependency injection

## Subdirectories

### Entities/
Domain objects that represent business concepts.

| Entity | Purpose |
|--------|---------|
| `ApiProvider` | Enum for supported LLM providers (Groq, Gemini) |
| `OutputResult` | Result of text output operations |
| `SelectedTextContext` | Context about currently selected text |
| `TranscriptionEntities` | Audio transcription related types |
| `ValidationState` | API key validation state |
| `VoiceCommandResult` | Result of voice command processing |

### Errors/
Domain-specific error types.

### Protocols/
Additional protocols not belonging to Repositories or UseCases.

### Repositories/
**Protocols** (interfaces) for data access. Implementations live in `Data/Repositories/`.

| Protocol | Purpose |
|----------|---------|
| `ApiKeyRepository` | Load/save API keys |
| `ApiKeyValidationRepository` | Validate API keys |
| `AppContextRepository` | Get active application context |
| `ExternalLinkRepository` | Open external links |
| `KeyMonitoringRepository` | Monitor keyboard events |
| `LLMRepository` | LLM inference calls |
| `PermissionRepository` | Check system permissions |
| `SelectedTextRepository` | Get selected text from active app |
| `TextOutputRepository` | Output text to active application |

### UseCases/
**Protocols** (interfaces) for business operations. Implementations live in `Data/UseCases/`.

| UseCase | Purpose |
|---------|---------|
| `GetSelectedTextUseCase` | Retrieve selected text from active app |
| `PolishTextUseCase` | Polish transcribed text via LLM |
| `ProcessVoiceCommandUseCase` | Process voice command with selected text |
| `RecordingControlUseCase` | Start/stop audio recording |
| `StopRecordingUseCase` | Stop recording and get audio data |
| `TranscribeAudioUseCase` | Transcribe audio to text |
| `TranscriptionUseCase` | High-level transcription orchestration |
| `ValidateApiKeyUseCase` | Validate API key with provider |

## Key Principles

1. **No UI imports** - Domain never imports SwiftUI or AppKit
2. **Protocols only** - No concrete implementations
3. **Sendable** - All types should be `Sendable` for concurrency safety
4. **Testable** - Can be tested without any infrastructure

## Usage

When AI needs to understand what the application does:
1. Start with Domain/Entities to understand data models
2. Look at Domain/UseCases to understand business operations
3. Check Domain/Repositories to understand data access patterns

Do NOT look at implementations in Data/ unless you need to modify how something works.