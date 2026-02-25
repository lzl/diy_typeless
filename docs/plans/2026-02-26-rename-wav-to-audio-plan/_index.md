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
| `WavData` (Swift) | `AudioData` | Swift UseCases |
| `wavData` parameter | `audioData` | Swift UseCase implementations |

**Out of scope**: `cli/src/commands/wav.rs` - This file actually handles WAV file analysis (diagnostic), keeping its name.

## Execution Plan

1. [Task 001: Rust AudioData Struct](./task-001-rust-struct.md) - Rename WavData to AudioData
2. [Task 002: Rust Transcribe Function](./task-002-rust-function.md) - Rename transcribe_wav_bytes
3. [Task 003: Rust FFI Exports](./task-003-rust-ffi.md) - Update lib.rs exports
4. [Task 004: Swift UseCase Implementations](./task-004-swift-usecase.md) - Update Impl files
5. [Task 005: Swift Protocol Definitions](./task-005-swift-protocol.md) - Update Protocol files
6. [Task 006: CLI Compatibility](./task-006-cli.md) - Update CLI imports
7. [Task 007: Regenerate FFI Bindings](./task-007-regenerate-ffi.md) - Run UniFFI
8. [Task 008: Verification](./task-008-verify.md) - Build and test

## Rollback Plan

If issues arise:
1. Revert the specific commit
2. All changes are atomic per task - can revert individual tasks

## Verification Criteria

- [ ] `cargo build -p diy_typeless_core` passes
- [ ] `cargo build -p diy-typeless-cli` passes
- [ ] `cargo test -p diy_typeless_core` passes
- [ ] `./scripts/dev-loop.sh --testing` passes (Xcode build)
