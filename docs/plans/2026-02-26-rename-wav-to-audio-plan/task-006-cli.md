# Task 006: Update CLI Compatibility

## Objective

Update CLI to use the new `AudioData` struct name from the core library.

## Files to Modify

1. `cli/src/main.rs` - Import statement

## BDD Scenario Reference

Scenario 6: CLI build passes

## Implementation Details

### In cli/src/main.rs:

The import statement does not need to change:
```rust
use diy_typeless_core::{start_recording, stop_recording};
```

This stays the same because:
- Function name `stop_recording` is unchanged
- Return type is inferred by the compiler (now `AudioData` instead of `WavData`)

However, if CLI code explicitly references the type, update it:
```rust
// If anywhere uses:
let data: WavData = stop_recording()?;
// Change to:
let data: AudioData = stop_recording()?;
```

Search for explicit type annotations (`: WavData`) and update them to `: AudioData`.

## Verification Steps

1. Build CLI: `cargo build -p diy-typeless-cli`
2. Expected: Clean build, no errors

## Dependencies

- **depends-on**: Task 001 (Rust struct rename)
  - CLI depends on core library exports

## Notes

- CLI may not explicitly name the type (using `let data = stop_recording()?`)
- Search for `: WavData` type annotations
- `cli/src/commands/wav.rs` is intentionally NOT renamed - it actually handles WAV files
