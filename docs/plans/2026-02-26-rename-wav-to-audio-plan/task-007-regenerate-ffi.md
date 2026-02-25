# Task 007: Regenerate UniFFI Bindings

## Objective

Regenerate the FFI bindings for Swift using UniFFI to reflect the new struct and function names.

## Files to Modify (Generated)

1. `app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.h`
2. `app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.modulemap`
3. `app/DIYTypeless/DIYTypeless/DIYTypelessCore.swift`

## BDD Scenario Reference

Scenario 7: Xcode build passes

## Implementation Details

### Step 1: Build the Rust core with UniFFI

```bash
cargo build -p diy_typeless_core --release
```

### Step 2: Regenerate bindings

```bash
cargo run -p diy_typeless_core --bin uniffi-bindgen generate \
  --library target/release/libdiy_typeless_core.dylib \
  --language swift \
  --out-dir app/DIYTypeless/DIYTypeless/
```

Note: Verify the exact command in the project or use existing scripts.

### Step 3: Update file locations

Ensure generated files are in the correct location:
- `app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.h`
- `app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.modulemap`
- `app/DIYTypeless/DIYTypeless/DIYTypelessCore.swift`

## Verification Steps

1. Check that `AudioData` appears in generated headers
2. Check that `transcribeAudioBytes` appears in generated Swift
3. Verify no `WavData` references remain in generated files

## Dependencies

- **depends-on**: Task 003 (Rust FFI exports)
  - UniFFI generates from Rust source

## Notes

- UniFFI generates Swift bindings automatically from Rust `#[uniffi::export]` macros
- The struct `AudioData` will be available in Swift as `AudioData`
- The function `transcribe_audio_bytes` becomes `transcribeAudioBytes` in Swift
- This is a generated file - do not hand-edit
