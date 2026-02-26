# Domain/UseCases - Protocol Index

This file provides an index of all use case protocols in the Domain layer.

## Use Case Protocols

| UseCase | File | Input | Output |
|---------|------|-------|--------|
| **GetSelectedTextUseCase** | `GetSelectedTextUseCase.swift` | None | `SelectedTextContext` |
| **PolishTextUseCase** | `PolishTextUseCase.swift` | `rawText: String, apiKey: String, context: String?` | `String` |
| **ProcessVoiceCommandUseCase** | `ProcessVoiceCommandUseCase.swift` | `audioData: Data, selectedText: String?` | `VoiceCommandResult` |
| **RecordingControlUseCase** | `RecordingControlUseCase.swift` | None | - |
| **StopRecordingUseCase** | `StopRecordingUseCase.swift` | None | `AudioData` |
| **TranscribeAudioUseCase** | `TranscribeAudioUseCase.swift` | `AudioData` | `String` |
| **TranscriptionUseCase** | `TranscriptionUseCase.swift` | `AudioData, apiKey: String, context: String?` | `String` |
| **ValidateApiKeyUseCase** | `ValidateApiKeyUseCase.swift` | `key: String, provider: ApiProvider` | `ValidationState` |

## Usage

Import the use cases you need:

```swift
import Domain

class MyState {
    private let polishTextUseCase: PolishTextUseCaseProtocol

    init(polishTextUseCase: PolishTextUseCaseProtocol) {
        self.polishTextUseCase = polishTextUseCase
    }

    func polish(text: String, apiKey: String) async throws -> String {
        try await polishTextUseCase.execute(rawText: text, apiKey: apiKey, context: nil)
    }
}
```