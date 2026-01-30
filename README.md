 # DIY Typeless
 
 DIY Typeless is a macOS app that lets you hold the **Right Option** key to record speech, release to transcribe with Groq Whisper, and polish with Gemini. The final text is pasted into the active text field or copied to the clipboard.
 
 ## Features
 
 - Push-to-talk voice capture (Right Option key)
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
   --out-dir app/DIYTypeless/RustCore
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
 ```
 
 ## macOS App Setup
 
 This repository provides the Swift sources but not a fully generated Xcode project file. Create a new macOS App project in Xcode and point it at `app/DIYTypeless/DIYTypeless` for sources.
 
 In Xcode:
 
 1. Add all Swift files from `app/DIYTypeless/DIYTypeless` to your target.
 2. Add the UniFFI-generated files from `app/DIYTypeless/RustCore`.
 3. Link the Rust dynamic library:
    - Add `target/release/libdiy_typeless_core.dylib` to **Link Binary With Libraries**.
    - Copy the dylib into the app bundle **Frameworks** folder.
 4. Ensure `Info.plist` includes `NSMicrophoneUsageDescription`.
 
 ## Permissions
 
 The app requires:
 
 - **Accessibility** (global key monitoring + paste simulation)
 - **Input Monitoring** (global keyboard events)
 - **Microphone** (audio recording)
 
 Open **System Settings → Privacy & Security** and enable:
 
 - Accessibility
 - Input Monitoring
 - Microphone
 
 ## Usage
 
 1. Launch the app.
 2. Grant required permissions.
 3. Save Groq and Gemini API keys.
 4. Hold **Right Option** to record; release to finish.
 5. The polished text will be pasted into the active field or copied.
 
 ## Notes
 
 - If Input Monitoring or Accessibility is missing, key capture will not work.
 - If no input field is focused, text is copied to the clipboard.
 - Re-generate UniFFI bindings whenever the Rust API changes.
 
