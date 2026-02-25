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

Update protocol method signature:
```swift
// Change:
func execute(wavData: WavData, apiKey: String, language: String?) async throws -> String
// To:
func execute(audioData: AudioData, apiKey: String, language: String?) async throws -> String
```

### In StopRecordingUseCase.swift:

Update protocol method signature:
```swift
// Change:
func execute() async throws -> WavData
// To:
func execute() async throws -> AudioData
```

## Verification Steps

1. Build: `./scripts/dev-loop.sh --testing`
2. Expected: Clean build, no Swift errors

## Dependencies

- **depends-on**: Task 004 (Swift UseCase implementations)
  - Protocols should be updated after implementations are ready
- **depends-on**: Task 007 (Regenerate FFI bindings)

## Notes

- Protocols define the contract between Domain and Data layers
- Must match the implementation signatures exactly
- Swift compiler will catch mismatches
