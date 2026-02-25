# Task 003: Update Rust FFI Exports

## Objective

Update the FFI exports in lib.rs to use the new names `AudioData` and `transcribe_audio_bytes`.

## Files to Modify

1. `core/src/lib.rs` - FFI export functions

## BDD Scenario Reference

Scenario 1, 2: Rust exports use new naming

## Implementation Details

### In core/src/lib.rs:

1. Update public re-export:
   ```rust
   // Change:
   pub use audio::WavData;
   // To:
   pub use audio::AudioData;
   ```

2. Update `stop_recording()` export:
   ```rust
   #[uniffi::export]
   pub fn stop_recording() -> Result<AudioData, CoreError> {
       audio::stop_recording()
   }
   ```

3. Update `stop_recording_wav()` export:
   ```rust
   #[uniffi::export]
   pub fn stop_recording_wav() -> Result<AudioData, CoreError> {
       audio::stop_recording_wav()
   }
   ```

4. Update `transcribe_wav_bytes()` export:
   ```rust
   #[uniffi::export]
   pub fn transcribe_audio_bytes(
       api_key: String,
       audio_bytes: Vec<u8>,  // was: wav_bytes
       language: Option<String>,
   ) -> Result<String, CoreError> {
       transcribe::transcribe_audio_bytes(&api_key, &audio_bytes, language.as_deref())
   }
   ```

## Verification Steps

1. Build core: `cargo build -p diy_typeless_core`
2. Expected: Clean build, no errors

## Dependencies

- **depends-on**: Task 001 (Rust struct rename)
- **depends-on**: Task 002 (Rust function rename)

## Notes

- UniFFI generates Swift bindings from these exports
- The parameter names in FFI don't affect generated code, but keep them consistent
- This is the bridge between Rust and Swift - critical to get right
