# Domain/Repositories - Protocol Index

This file provides an index of all repository protocols in the Domain layer.

## Repository Protocols

| Protocol | File | Description |
|----------|------|-------------|
| **ApiKeyRepository** | `ApiKeyRepository.swift` | Load, save, delete API keys |
| **AppContextRepository** | `AppContextRepository.swift` | Get current application context |
| **ExternalLinkRepository** | `ExternalLinkRepository.swift` | Open external URLs |
| **KeyMonitoringRepository** | `KeyMonitoringRepository.swift` | Capture keyboard events |
| **LLMRepository** | `LLMRepository.swift` | LLM inference operations |
| **PermissionRepository** | `PermissionRepository.swift` | System permission checks |
| **SelectedTextRepository** | `SelectedTextRepository.swift` | Get/set clipboard text |
| **TextOutputRepository** | `TextOutputRepository.swift` | Output text to applications |

## Usage

Import the protocols you need:

```swift
import Domain

class MyService {
    private let apiKeyRepository: ApiKeyRepository

    init(apiKeyRepository: ApiKeyRepository) {
        self.apiKeyRepository = apiKeyRepository
    }
}
```