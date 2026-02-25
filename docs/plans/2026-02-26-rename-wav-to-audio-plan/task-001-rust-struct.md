# Task 001: Rename WavData to AudioData in Rust

## Objective

Rename the `WavData` struct to `AudioData` in the Rust core library to reflect that it holds FLAC-compressed audio data, not WAV format.

## Files to Modify

1. `core/src/audio.rs` - Struct definition and usage
2. `core/src/lib.rs` - Public re-export

## BDD Scenario Reference

Scenario 1: Rust AudioData struct exists

## Implementation Details

### In core/src/audio.rs:
- Rename `pub struct WavData` to `pub struct AudioData`
- Update the `#[derive(Debug, uniffi::Record)]` line
- Update all function return types that use `WavData`
  - `stop_recording()`
  - `stop_recording_wav()`
- Keep struct fields unchanged: `bytes: Vec<u8>`, `duration_seconds: f32`

### In core/src/lib.rs:
- Change `pub use audio::WavData;` to `pub use audio::AudioData;`
- Update `stop_recording()` return type
- Update `stop_recording_wav()` return type

## Verification Steps

1. Build core: `cargo build -p diy_typeless_core`
2. Expected: Clean build, no errors

## Dependencies

None - This is the first task.

## Notes

- `stop_recording_wav()` actually does return WAV format (for CLI diagnostics)
- The struct holds bytes generically - actual format depends on which function created it
- New name `AudioData` is format-agnostic, which is correct
