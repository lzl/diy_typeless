# Task 005: Update Swift Protocol Definitions

## Objective

Update Swift protocol definitions to use `AudioData` instead of `WavData`.

## Files to Modify

1. `app/DIYTypeless/DIYTypeless/Domain/UseCases/TranscribeAudioUseCase.swift`
2. `app/DIYTypeless/DIYTypeless/Domain/UseCases/StopRecordingUseCase.swift`

## BDD Scenario Reference

Scenario 3, 4: Swift protocols use correct naming

## Implementation Details

### In TranscribeAudioUseCase.swift:

1. Update protocol method signature:
```swift
// Change:
func execute(wavData: WavData, apiKey: String, language: String?) async throws -> String
// To:
func execute(audioData: AudioData, apiKey: String, language: String?) async throws -> String
```

2. Update documentation comments:
```swift
// Change:
/// - Parameter wavData: The WAV audio data to transcribe

// To:
/// - Parameter audioData: The audio data to transcribe (FLAC format)
```

### In StopRecordingUseCase.swift:

1. Update protocol method signature:
```swift
// Change:
func execute() async throws -> WavData
// To:
func execute() async throws -> AudioData
```

2. Update Sendable extension:
```swift
// Change:
extension WavData: @unchecked Sendable {}

// To:
extension AudioData: @unchecked Sendable {}
```

3. Update documentation comments:
```swift
// Change:
/// Stops the current recording and returns the WAV audio data

// To:
/// Stops the current recording and returns the audio data (FLAC format)
```

## Verification Steps

1. Build: `./scripts/dev-loop.sh --testing`
2. Expected: Clean build, no Swift errors

## Dependencies

- **depends-on**: Task 007 (Regenerate FFI bindings)
  - Protocols reference `AudioData` from generated FFI

## Notes

- Protocols define the contract between Domain and Data layers
- Domain is the inner layer, Data is the outer layer
- Protocols must be defined BEFORE implementations (Clean Architecture dependency rule)
- Swift compiler will catch mismatches between protocol and implementation
