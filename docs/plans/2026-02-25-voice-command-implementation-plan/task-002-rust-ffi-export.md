# Task 002: Rust FFI Export

## Goal
Export `process_text_with_llm` function via UniFFI for Swift consumption.

## Implementation Steps

### 1. Modify File
Modify `core/src/lib.rs`

### 2. Add Module Declaration
```rust
mod llm_processor;
```

### 3. Add FFI Export
```rust
#[uniffi::export]
pub fn process_text_with_llm(
    api_key: String,
    prompt: String,
    system_instruction: Option<String>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    llm_processor::process_text_with_llm(
        &api_key,
        &prompt,
        system_instruction.as_deref(),
        temperature,
    )
}
```

## Verification

### Build and Generate FFI
```bash
cargo build -p diy_typeless_core --release
# UniFFI will auto-generate Swift bindings
cargo run --bin uniffi-bindgen generate --library target/release/libdiy_typeless_core.dylib --language swift --out-dir app/DIYTypeless/DIYTypeless/
```

### Verify Swift Binding
Check that `processTextWithLLM` function is available in generated `DIYTypelessCore.swift`.

## Dependencies
- Task 001: llm_processor.rs must be complete

## Commit Message
```
feat(core): export process_text_with_llm via FFI

- Add llm_processor module declaration
- Export process_text_with_llm for Swift consumption
- Regenerate UniFFI bindings

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
