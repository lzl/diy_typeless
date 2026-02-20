# Agent Guidance

## Language Convention

All code, documentation, comments, commit messages, and technical writing in this project must be in English. This includes:
- Rust code and comments
- Swift code and comments
- CLI output and error messages
- Documentation files (README, AGENTS.md, etc.)
- Git commit messages
- Test case descriptions and evolution logs
- Skill documentation

The only exception is user-facing content that is intentionally localized (e.g., test cases for Chinese language processing).

## User Preferences (Important)

### Logging

**Always use file-based logs. NEVER ask the user to use Console.app.**

- Log files should be written to `/tmp/` directory
- Tell the user the exact file path to retrieve
- The user will send log files directly, not use Console.app

### Closing the Loop (Primary Rule)

This project prioritizes closing the loop. Any core logic changes must be verified through an executable path that the agent can run end-to-end without opening the macOS app UI.

Required workflow:

1. Implement Rust core logic first.
2. Expose the same code paths through the Rust CLI.
3. Build and run the CLI to validate behavior.
4. Only after CLI validation, integrate the Rust core into the macOS app.
5. If the app changes break the CLI or the core logic, fix the core and CLI first.

If there is uncertainty, extend the CLI with additional flags or diagnostics so the agent can re-run and confirm fixes.

## Xcode Build & Debug (Command Line)

When working with the macOS app, use `xcodebuild` command line tool instead of opening the Xcode GUI. This enables automated error collection and debugging.

### Project Location

The Xcode project is located at:
```
/Users/lzl/Documents/GitHub/diy_typeless_mac/DIYTypeless/DIYTypeless.xcodeproj
```

### Build Commands

**Debug build:**
```bash
cd /Users/lzl/Documents/GitHub/diy_typeless_mac/DIYTypeless
xcodebuild -scheme DIYTypeless -configuration Debug build 2>&1
```

**Release archive (arm64 only):**
```bash
cd /Users/lzl/Documents/GitHub/diy_typeless_mac/DIYTypeless
xcodebuild archive -scheme DIYTypeless -archivePath ~/Downloads/DIYTypeless.xcarchive ARCHS=arm64 ONLY_ACTIVE_ARCH=NO 2>&1
```

### Error Handling Workflow

1. Run the build command and capture output
2. If build fails, parse the error output (look for `error:` lines)
3. Common issues:
   - **Architecture mismatch**: Rust library only supports arm64. Use `ARCHS=arm64` flag.
   - **Missing entitlements**: Ensure Release config has `CODE_SIGN_ENTITLEMENTS` set.
   - **Library not found**: Run `cargo build -p diy_typeless_core --release` first.
4. Fix issues and re-run build to verify

### Creating DMG for Distribution

Use the provided script:
```bash
./scripts/build-dmg.sh
```

This builds the app, creates a DMG, and outputs to `~/Downloads/DIYTypeless.dmg`.

## Key Event Capture (Important)

This app does NOT have Input Monitoring permission (deliberately dropped in PR #10). This means:

- **`NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`** will silently fail for non-modifier keys (Esc, letters, etc.)
- **`CGEvent.tapCreate`** for `.keyDown` events will return nil
- **Only `.flagsChanged`** global monitoring works (modifier keys like Fn)

**Correct approach for capturing non-modifier keys (e.g. Esc):** Use an `NSPanel` subclass with `.nonactivatingPanel` style mask and `canBecomeKey = true`. When the panel is made key via `makeKey()`, it receives local keyboard events without activating the app or stealing focus from the user's text field. Override `sendEvent(_:)` on the panel to intercept specific keys. See `CapsulePanel` in `CapsuleWindow.swift` for the working implementation.

Do NOT attempt: `NSEvent` global `.keyDown` monitors, `CGEventTap`, or `IOHIDManager` for key capture — they all require Input Monitoring permission.

## UniFFI Generated Files (Important)

UniFFI auto-generates C header and modulemap files for the Rust-Swift bridge. These files must live in **one and only one** location:

```
app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.h
app/DIYTypeless/DIYTypeless/DIYTypelessCoreFFI.modulemap
```

This is because:
- The bridging header (`DIYTypeless-Bridging-Header.h`) does `#import "DIYTypelessCoreFFI.h"` relative to itself in the same directory.
- `SWIFT_INCLUDE_PATHS` in `project.pbxproj` is set to `$(SRCROOT)/DIYTypeless`, which resolves to `app/DIYTypeless/DIYTypeless/`.

Do NOT place copies of these files in `app/DIYTypeless/` (the parent directory). That path is not referenced by the Xcode project and creates confusing duplicates.

## Lesson: Use DispatchQueue instead of Swift Concurrency for macOS UI Work

**Issue**: When implementing streaming ASR with Swift Concurrency (`Task`, `await`, `Task.detached`), UI animations (progress bars) were choppy and blocked.

**Root Cause**: Swift Concurrency's `Task` and `await` mechanisms can interfere with UI animation smoothness on macOS, even when correctly dispatched to background threads. The interaction between Swift Concurrency's structured concurrency and AppKit's runloop can cause unexpected blocking of UI updates.

**Solution**: Use `DispatchQueue.global(qos: .userInitiated).async` for background work and `DispatchQueue.main.async` for UI updates. This pattern provides more predictable behavior for macOS UI animations, especially when mixing synchronous C/Rust FFI calls with UI updates.

**Rule**: For macOS UI work requiring smooth animations, prefer `DispatchQueue` over Swift Concurrency. Do not use `Task`, `await`, or `Task.detached` for background-to-UI transitions without explicit testing of animation smoothness.
