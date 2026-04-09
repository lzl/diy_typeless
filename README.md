# DIY Typeless

DIY Typeless is a macOS app that lets you hold **Fn** to record speech, release to transcribe with Groq Whisper, polish with Gemini, and paste the final text into the active field (or copy to clipboard).

## Features

- Push-to-talk voice capture with **Fn**
- Whisper Large v3 Turbo transcription
- Gemini Flash Lite text polishing
- Automatic paste with clipboard fallback
- Rust core + Swift macOS app

## Requirements

- macOS 13+
- Xcode 15+ (for local app builds)
- Rust toolchain (stable, for core/CLI development)
- Groq API key
- Gemini API key

## Repository Structure

- `core/` - Rust core library
- `cli/` - CLI for end-to-end validation
- `app/DIYTypeless/` - macOS app + UniFFI bridge
- `scripts/` - build and utility scripts

## Quick Start (Contributors)

```bash
# Build Rust core
cargo build -p diy_typeless_core --release

# Validate core pipeline through CLI
GROQ_API_KEY=your_key GEMINI_API_KEY=your_key \
cargo run -p diy_typeless_cli -- full --duration-seconds 4

# Verify macOS app build without launching
./scripts/dev-loop-build.sh --testing

# Codex-compatible local build/run entrypoint
./script/build_and_run.sh --verify
```

For full CLI diagnostics, debug loops, and agent/developer workflow rules, see [AGENTS.md](AGENTS.md).

## Usage

1. Launch the app.
2. Grant Microphone and Accessibility permissions.
3. Save Groq and Gemini API keys.
4. Hold **Fn** to record and release to finish.
5. Use the polished output pasted into the active field (or from clipboard fallback).

## Permissions

The app needs:

- **Microphone** for recording audio
- **Accessibility** for global key handling and paste automation

If the app does not appear in System Settings permission lists, run it once from Xcode and retry.

## License

This project is dual-licensed under either:

- MIT License ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)

at your option.
