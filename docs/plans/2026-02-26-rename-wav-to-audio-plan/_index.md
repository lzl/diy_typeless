# Rename WAV to Audio: Implementation Plan

## Goal

Eliminate naming confusion where audio data is labeled as "WAV" but is actually FLAC format. Rename all identifiers from "wav" to "audio" to reflect the actual data format.

## Problem Statement

- `WavData` struct holds FLAC-compressed bytes, not WAV
- `transcribe_wav_bytes()` receives FLAC data but name suggests WAV
- This confusion led to the MIME type bug we just fixed

## Architecture Impact

This change affects the FFI boundary between Rust and Swift:

```
Rust Core (core/src/)
├── lib.rs          - FFI exports
├── audio.rs        - WavData struct
└── transcribe.rs   - transcribe_wav_bytes function

Swift App (app/DIYTypeless/DIYTypeless/)
├── Data/UseCases/     - Implementation
├── Domain/UseCases/   - Protocol definitions
└── DIYTypelessCore.swift  - FFI imports
```

## Naming Changes

| Current | New | Location |
|---------|-----|----------|
| `WavData` | `AudioData` | core/src/audio.rs |
| `transcribe_wav_bytes` | `transcribe_audio_bytes` | core/src/transcribe.rs, lib.rs |
| `WavData` (Swift) | `AudioData` | Swift UseCases + Sendable extension |
| `wavData` parameter | `audioData` | Swift UseCase implementations |
| `transcribeWavBytes` | `transcribeAudioBytes` | Swift FFI calls |

**Out of scope (intentionally)**:
- `cli/src/commands/wav.rs` - This file actually handles **real WAV file analysis** (diagnostic tool), keeping its name is correct.
- Comments and documentation strings will be updated as part of each task, not as a separate task.

## Execution Plan

### Phase 1: Rust Core Changes
1. [Task 001: Rust AudioData Struct](./task-001-rust-struct.md) - Rename WavData to AudioData
2. [Task 002: Rust Transcribe Function](./task-002-rust-function.md) - Rename transcribe_wav_bytes
3. [Task 003: Rust FFI Exports](./task-003-rust-ffi.md) - Update lib.rs exports

### Phase 2: FFI & Swift Data Layer
4. [Task 007: Regenerate FFI Bindings](./task-007-regenerate-ffi.md) - Run UniFFI (generates Swift types)
5. [Task 006: CLI Compatibility](./task-006-cli.md) - Update CLI imports

### Phase 3: Swift Domain & Data Layers (Clean Architecture order: Domain first!)
6. [Task 005: Swift Protocol Definitions](./task-005-swift-protocol.md) - Update Domain layer protocols (inner layer)
7. [Task 004: Swift UseCase Implementations](./task-004-swift-usecase.md) - Update Data layer implementations (outer layer)

### Phase 4: Verification
8. [Task 008: Verification](./task-008-verify.md) - Build and test

## Rollback Plan

If issues arise:
1. Revert the specific commit
2. All changes are atomic per task - can revert individual tasks

## Verification Criteria

- [ ] `cargo build -p diy_typeless_core` passes
- [ ] `cargo build -p diy-typeless-cli` passes
- [ ] `cargo test -p diy_typeless_core` passes
- [ ] `./scripts/dev-loop-build.sh --testing` passes (Xcode build)
