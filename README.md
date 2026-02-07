 # DIY Typeless
 
 DIY Typeless is a macOS app that lets you hold the **Fn** key to record speech, release to transcribe with Groq Whisper, and polish with Gemini. The final text is pasted into the active text field or copied to the clipboard.
 
 ## Features
 
 - Push-to-talk voice capture (Fn key)
 - Groq Whisper v3 transcription
 - Gemini Flash Lite text polishing
 - Automatic paste into focused input field (or clipboard fallback)
 - Rust core with Swift UI
 - CLI for fast, repeatable testing
 
 ## Requirements
 
 - macOS 13+
 - Xcode 15+
 - Rust toolchain (stable)
 - Groq API key
 - Gemini API key
 
## Repository Structure

- `core/` — Rust core library (audio capture + Groq + Gemini)
- `cli/` — CLI for end-to-end testing
- `app/DIYTypeless/` — Swift UI layer + UniFFI bindings
- `scripts/` — Setup and utility scripts
 
 ## Setup
 
 1. Install Rust:
 
 ```bash
 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
 ```
 
 2. Build the Rust core:
 
 ```bash
 cargo build -p diy_typeless_core --release
 ```
 
3. Generate Swift bindings:

```bash
uniffi-bindgen generate \
  --library target/release/libdiy_typeless_core.dylib \
  --language swift \
  --out-dir app/DIYTypeless/DIYTypeless
```
 
 ## CLI Usage (Closing the Loop)
 
 The CLI exercises the same Rust core logic used by the macOS app. Always verify changes here first.
 
 ```bash
 # Record a short clip (auto-start)
 cargo run -p diy_typeless_cli -- record --duration-seconds 3

 # Full pipeline (record -> transcribe -> polish)
 GROQ_API_KEY=your_key GEMINI_API_KEY=your_key \
 cargo run -p diy_typeless_cli -- full --duration-seconds 4
 ```
 
 The CLI automatically loads a local `.env` file if present.
 
 Additional commands:
 
 ```bash
 # Transcribe an existing wav file
 cargo run -p diy_typeless_cli -- transcribe ./audio.wav
 
 # Polish a text string (reads stdin if --text not provided)
 echo "raw transcript" | cargo run -p diy_typeless_cli -- polish
 
 # Print environment diagnostics (keys/tooling/path checks)
 cargo run -p diy_typeless_cli -- diagnose env
 
 # Capture a timed diagnostic clip and print WAV metrics
 cargo run -p diy_typeless_cli -- diagnose audio --duration-seconds 2
 
 # Run pipeline diagnostics on an existing wav file
 GROQ_API_KEY=your_key GEMINI_API_KEY=your_key \
 cargo run -p diy_typeless_cli -- diagnose pipeline ./audio.wav
 ```
 
## Fast Debug Loop (CLI + xcodebuild)

Use one command to rebuild Rust core, build the app with `xcodebuild`, install to a stable path, and relaunch.

```bash
./scripts/dev-loop.sh
```

By default it:

1. Builds `diy_typeless_core` with a profile inferred from `--configuration` (`Debug -> debug`, `Release -> release`).
2. Builds the app in Debug with `xcodebuild`.
3. Copies the bundle to `~/Applications/DIYTypeless Dev.app`.
4. Launches the copied app.

Useful flags:

```bash
# Build/install only (no launch)
./scripts/dev-loop.sh --skip-launch

# Reset Accessibility before launch
./scripts/dev-loop.sh --reset-permissions

# Also reset Microphone
./scripts/dev-loop.sh --reset-permissions --include-microphone-reset

# Install somewhere else
./scripts/dev-loop.sh --destination-dir ./.context/apps

# Build Release app + release Rust dylib
./scripts/dev-loop.sh --configuration Release --skip-launch
```

Reset permissions only:

```bash
./scripts/reset-permissions.sh
./scripts/reset-permissions.sh --include-microphone
```

Recommended day-to-day debug flow:

```bash
# 1) Validate Rust core behavior first (closing the loop)
cargo run -p diy_typeless_cli -- full --duration-seconds 4

# 2) Rebuild + reinstall + relaunch macOS app
./scripts/dev-loop.sh

# 3) If permission UI does not refresh after an update
./scripts/dev-loop.sh --reset-permissions
```

## macOS App

The Xcode project and Swift sources are in this repository:

- `app/DIYTypeless/DIYTypeless.xcodeproj`
- `app/DIYTypeless/DIYTypeless/`
 
## Permissions

The app requires:

- **Accessibility** (global key monitoring + paste simulation)
- **Microphone** (audio recording)

### Granting Permissions

Open **System Settings → Privacy & Security** and enable the app under:

- Accessibility
- Microphone

### App Not Appearing in Permission Lists?

If the app doesn't appear in the Accessibility list:

1. **Run from Xcode first** — When you run the app from Xcode, macOS registers it for permission requests. Click "Request Permissions" in the app.

2. **Quit and reopen System Settings** — Sometimes the Settings app needs to be fully closed and reopened to refresh the list.

3. **Check signing** — The app must be code-signed (at least with a local development certificate). In Xcode:
   - Go to **Signing & Capabilities**
   - Ensure "Automatically manage signing" is enabled
   - Select your development team

4. **Manual addition** — If the app still doesn't appear:
   - Click the **+** button in the permission list
   - Navigate to `~/Library/Developer/Xcode/DerivedData/DIYTypeless-*/Build/Products/Debug/DIYTypeless.app`
   - (The exact path depends on your build configuration)

5. **Reset permissions (last resort)**:
   ```bash
   ./scripts/reset-permissions.sh

   # Also reset microphone if needed
   ./scripts/reset-permissions.sh --include-microphone
   ```
   Then run `./scripts/dev-loop.sh` and request permissions again.
 
 ## Usage
 
 1. Launch the app.
 2. Grant required permissions.
 3. Save Groq and Gemini API keys.
 4. Hold **Fn** to record; release to finish.
 5. The polished text will be pasted into the active field or copied.
 
 ## Notes
 
 - If Accessibility is missing, key capture will not work.
 - If no input field is focused, text is copied to the clipboard.
 - Re-generate UniFFI bindings whenever the Rust API changes.
 
