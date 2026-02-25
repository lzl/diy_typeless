# Task 006: Update CLI Compatibility

## Objective

Update CLI to use the new `AudioData` struct name from the core library.

## Files to Modify

1. `cli/src/main.rs` - Import statement

## BDD Scenario Reference

Scenario 6: CLI build passes

## Implementation Details

### In cli/src/main.rs:

Update the import:
```rust
// Change:
use diy_typeless_core::{start_recording, stop_recording};
// To:
use diy_typeless_core::{start_recording, stop_recording};
```

Note: The import itself doesn't change because we still use `stop_recording` which now returns `AudioData` instead of `WavData`. The type inference handles this.

However, if CLI code explicitly references the type, update it:
```rust
// If anywhere uses:
let data: WavData = stop_recording()?;
// Change to:
let data: AudioData = stop_recording()?;
```

Search for explicit type annotations and update them.

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
