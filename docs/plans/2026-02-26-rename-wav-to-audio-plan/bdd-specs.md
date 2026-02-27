# BDD Specifications: Rename WAV to Audio

## Scenario 1: Rust AudioData struct exists

**Given** the Rust core library is compiled
**When** I check the public exports
**Then** I should see `AudioData` struct (not `WavData`)
**And** it should have `bytes: Vec<u8>` and `duration_seconds: f32` fields

## Scenario 2: Rust transcribe_audio_bytes function exists

**Given** the Rust core library is compiled
**When** I check the public exports
**Then** I should see `transcribe_audio_bytes` function (not `transcribe_wav_bytes`)
**And** it should accept `api_key: &str`, `audio_bytes: &[u8]`, `language: Option<&str>`
**And** it should return `Result<String, CoreError>`

## Scenario 3: Swift UseCase uses AudioData

**Given** the Swift app is compiled
**When** I check the StopRecordingUseCase protocol
**Then** it should return `AudioData` (not `WavData`)

## Scenario 4: Swift TranscribeUseCase uses correct naming

**Given** the Swift app is compiled
**When** I check the TranscribeAudioUseCaseImpl
**Then** it should call `transcribeAudioBytes` (not `transcribeWavBytes`)
**And** the parameter should be named `audioData` (not `wavData`)

## Scenario 5: End-to-end transcription works

**Given** I have a valid Groq API key
**When** I record audio and transcribe it
**Then** I should receive the transcribed text
**And** the audio should be sent as FLAC format to Groq API

## Scenario 6: CLI build passes

**Given** I build the CLI
**When** I run `cargo build -p diy-typeless-cli`
**Then** it should compile without errors
**And** the `stop_recording` function should return `AudioData`

## Scenario 7: Xcode build passes

**Given** I build the macOS app
**When** I run `./scripts/dev-loop-build.sh --testing`
**Then** it should build without errors
**And** all Swift files should reference `AudioData` (not `WavData`)
