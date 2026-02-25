# Task 002: Rename transcribe_wav_bytes to transcribe_audio_bytes

## Objective

Rename the `transcribe_wav_bytes` function to `transcribe_audio_bytes` to accurately reflect that it processes audio data (now FLAC format).

## Files to Modify

1. `core/src/transcribe.rs` - Function definition

## BDD Scenario Reference

Scenario 2: Rust transcribe_audio_bytes function exists

## Implementation Details

### In core/src/transcribe.rs:
- Rename `pub fn transcribe_wav_bytes` to `pub fn transcribe_audio_bytes`
- Rename parameter `wav_bytes` to `audio_bytes`
- Update internal comments if they reference "wav"

### Function signature stays the same:
```rust
pub fn transcribe_audio_bytes(
    api_key: &str,
    audio_bytes: &[u8],  // was: wav_bytes
    language: Option<&str>,
) -> Result<String, CoreError>
```

## Verification Steps

1. Build core: `cargo build -p diy_typeless_core`
2. Expected: Clean build, no errors

## Dependencies

- **depends-on**: Task 001 (Rust struct rename)
  - While technically independent, keeping struct and function renames together ensures consistency

## Notes

- The function uploads to Groq API with `audio/flac` MIME type (already fixed)
- The parameter rename from `wav_bytes` to `audio_bytes` makes the code self-documenting
