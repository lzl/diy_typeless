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

## Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/) format for all commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Common types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Test-related changes
- `chore` - Build/tooling changes

**Examples:**
```
feat(asr): add streaming support for local Qwen3-ASR

fix(cli): handle empty audio input gracefully

docs(agents): add commit message convention
```

**Rules:**
- Use lowercase for type and scope
- Use present tense ("add" not "added")
- Keep the first line under 72 characters
- Reference issues/PRs in footer when applicable

## Closing the Loop (Primary Rule)

This project prioritizes closing the loop. Any core logic changes must be verified through an executable path that the agent can run end-to-end without opening the macOS app UI.

Required workflow:

1. Implement Rust core logic first.
2. Expose the same code paths through the Rust CLI.
3. Build and run the CLI to validate behavior.
4. Only after CLI validation, integrate the Rust core into the macOS app.
5. If the app changes break the CLI or the core logic, fix the core and CLI first.

If there is uncertainty, extend the CLI with additional flags or diagnostics so the agent can re-run and confirm fixes.

## Clean Architecture Guidelines

### Layer Structure

```
Presentation (SwiftUI Views + @Observable ViewModels)
         ↓
Domain (UseCases + Entities + Repository Protocols)
         ↓
Data (Repository Implementations + SwiftData)
         ↓
Infrastructure (FFI Bridge + Network)
```

### Dependency Direction

All dependencies point **inward** toward Domain. Outer layers depend on inner layers through protocols.

```
Domain Layer (no external dependencies)
    ↑
Data Layer (depends on Domain)
    ↑
Presentation Layer (depends on Domain and Data)
    ↑
Infrastructure Layer (depends on all above)
```

### Mandatory Rules

1. **Views** must not contain business logic; delegate to ViewModels
2. **ViewModels** must be `@MainActor @Observable`, never `ObservableObject`
3. **UseCases** encapsulate single business operations; pure Swift, no UI framework imports
4. **Repositories** abstract data sources; protocols in Domain, implementations in Data
5. **SwiftData Models** must not be exposed to Presentation layer; map to Domain entities
6. **FFI calls** must be wrapped in async continuations; never call synchronously from MainActor
7. **Dependencies** must be injected via constructors; singletons are prohibited

## SwiftUI State Management

### Use @Observable (Not ObservableObject)

All ViewModels must use the modern `@Observable` macro:

```swift
// CORRECT
@MainActor
@Observable
final class AppState {
    private(set) var phase: Phase = .onboarding
}

// WRONG - Do not use
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var phase: Phase = .onboarding
}
```

### View Property Wrappers

```swift
struct ContentView: View {
    // For root state passed via environment
    @State private var appState = AppState()

    // For observable objects (prefer @Observable instead)
    // @StateObject is DEPRECATED for new code

    var body: some View {
        ChildView()
            .environment(appState)
    }
}

struct ChildView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Text(appState.phase.description)
    }
}
```

## Swift Concurrency and FFI Integration

### Wrapping Synchronous FFI Calls

Synchronous C/Rust FFI calls block threads. Wrap them using `withCheckedContinuation` to bridge to Swift Concurrency without blocking the MainActor.

```swift
// Domain/UseCases/TranscriptionUseCase.swift
protocol TranscriptionUseCaseProtocol {
    func transcribe(audio: Data) async throws -> String
}

final class TranscriptionUseCase: TranscriptionUseCaseProtocol {
    func transcribe(audio: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try rust_transcribe(audio)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// Presentation/State/RecordingState.swift
@MainActor
@Observable
final class RecordingState {
    private let transcriptionUseCase: TranscriptionUseCaseProtocol

    func startTranscription() async {
        isLoading = true
        defer { isLoading = false }

        do {
            result = try await transcriptionUseCase.transcribe(audio: audioData)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### Rules for Concurrency

1. **Never** call synchronous FFI from MainActor directly
2. **Always** use `withCheckedContinuation` or `withCheckedThrowingContinuation`
3. **Always** dispatch blocking work to `DispatchQueue.global(qos: .userInitiated)`
4. **Never** use `nonisolated(unsafe)` as a workaround
5. **Always** mark ViewModels with `@MainActor`

## Repository Pattern

### Protocol in Domain

```swift
// Domain/Repositories/ApiKeyRepository.swift
protocol ApiKeyRepository: Sendable {
    func loadKey(for provider: ApiProvider) -> String?
    func saveKey(_ key: String, for provider: ApiProvider) throws
    func deleteKey(for provider: ApiProvider) throws
}

enum ApiProvider: Sendable {
    case groq
    case gemini
}
```

### Implementation in Data

```swift
// Data/Repositories/KeychainApiKeyRepository.swift
import Security

final class KeychainApiKeyRepository: ApiKeyRepository {
    func loadKey(for provider: ApiProvider) -> String? {
        // Keychain implementation
    }

    func saveKey(_ key: String, for provider: ApiProvider) throws {
        // Keychain implementation
    }

    func deleteKey(for provider: ApiProvider) throws {
        // Keychain implementation
    }
}
```

### Usage in ViewModel

```swift
@MainActor
@Observable
final class OnboardingState {
    private let apiKeyRepository: ApiKeyRepository

    init(apiKeyRepository: ApiKeyRepository = KeychainApiKeyRepository()) {
        self.apiKeyRepository = apiKeyRepository
    }
}
```

## Dependency Injection

### Constructor Injection (Preferred)

```swift
@MainActor
@Observable
final class AppState {
    private let permissionManager: PermissionManagerProtocol
    private let apiKeyRepository: ApiKeyRepository

    init(
        permissionManager: PermissionManagerProtocol = PermissionManager(),
        apiKeyRepository: ApiKeyRepository = KeychainApiKeyRepository()
    ) {
        self.permissionManager = permissionManager
        self.apiKeyRepository = apiKeyRepository
    }
}
```

### Environment Injection (For SwiftUI Views)

```swift
// Define environment key
private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

// Usage in preview or tests
ContentView()
    .environment(AppState(
        permissionManager: MockPermissionManager(),
        apiKeyRepository: MockApiKeyRepository()
    ))
```

## Xcode Build & Debug (Command Line)

When working with the macOS app, use `xcodebuild` command line tool instead of opening the Xcode GUI. This enables automated error collection and debugging.

### Quick Build Verification

To verify the app builds successfully without launching it or modifying permissions:

```bash
./scripts/dev-loop-build.sh --testing
```

This is the **only** way to validate macOS app builds during development. Do not use direct `xcodebuild` commands.

### Error Handling Workflow

1. Run `./scripts/dev-loop-build.sh --testing`
2. If build fails, parse the error output (look for `error:` lines)
3. Common issues:
   - **Architecture mismatch**: Rust library only supports arm64
   - **Missing entitlements**: Ensure Release config has `CODE_SIGN_ENTITLEMENTS` set
   - **Library not found**: Run `cargo build -p diy_typeless_core --release` first
4. Fix issues and re-run build to verify

### Creating DMG for Distribution

Use the provided script:
```bash
./scripts/prod-dmg-build.sh
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

## Testing Strategy

### Unit Tests Only (DIYTypelessTests)

**MANDATORY:** Only run Unit Tests (`DIYTypelessTests` target). DO NOT run UI Tests (`DIYTypelessUITests`) as they:
- Launch the full App, triggering Keychain password prompts
- Require macOS UI automation permissions (Touch ID dialog)
- Cannot run unattended

Run unit tests with:
```bash
xcodebuild test \
    -project app/DIYTypeless/DIYTypeless.xcodeproj \
    -scheme DIYTypeless \
    -only-testing DIYTypelessTests \
    -destination 'platform=macOS'
```

Unit Tests use mocked dependencies (`MockApiKeyRepository`, `MockPermissionRepository`) to avoid:
- Keychain access prompts
- Accessibility/Microphone permission checks
- Real network calls

Example test with mocks:
```swift
@MainActor
@Suite("RecordingState Tests")
struct RecordingStateTests {
    @Test("Parallel execution reduces total delay")
    func testParallelExecution() async throws {
        let mockGetSelectedText = MockGetSelectedTextUseCase()
        let mockStopRecording = MockStopRecordingUseCase()
        let state = RecordingStateTestFactory.makeRecordingState(
            stopRecordingUseCase: mockStopRecording,
            getSelectedTextUseCase: mockGetSelectedText
        )
        // Test logic without real permissions/keychain
    }
}
```

### Crash Recovery Protocol

If tests crash during execution, follow this protocol:

1. **Locate crash logs:**
   ```bash
   ls -la ~/Library/Logs/DiagnosticReports/DIYTypeless*.ips
   ```

2. **Analyze the crash:**
   - Look for `Exception Type`, `Crashed Thread`, and `Thread 0` backtrace
   - Identify if it's a Rust FFI issue, Swift code issue, or resource issue

3. **Common fixes:**
   - **Rust dylib mismatch:** Run `cargo build -p diy_typeless_core` (or `--release`)
   - **DerivedData corruption:** `rm -rf .context/DerivedData`
   - **Architecture mismatch:** Ensure Rust and Xcode both build for arm64

4. **Re-run tests:**
   - Apply fixes and re-run unit tests
   - Repeat until tests pass without crashes

5. **DO NOT** ignore crashes or skip failing tests. Fix the root cause.

## File Naming Conventions

Use these patterns when creating new files:

| Pattern | Layer | Example |
|---------|-------|---------|
| `XXXRepository.swift` | Domain (Protocol) | `ApiKeyRepository.swift` |
| `XXXRepository.swift` | Data (Implementation) | `KeychainApiKeyRepository.swift` |
| `XXXUseCase.swift` | Domain (Protocol) | `PolishTextUseCase.swift` |
| `XXXUseCaseImpl.swift` | Data (Implementation) | `PolishTextUseCaseImpl.swift` |
| `XXXState.swift` | State | `RecordingState.swift` |
| `XXXEntities.swift` | Domain/Entities | `TranscriptionEntities.swift` |
| `XXXError.swift` | Domain/Errors | `ValidationError.swift` |

## Test File Naming

| Pattern | Example |
|---------|---------|
| `XXXTests.swift` | `RecordingStateTests.swift` |
| `XXXTestFactory.swift` | `RecordingStateTestFactory.swift` |
| `MockXXX.swift` | `MockGetSelectedTextUseCase.swift` |

## Directory Structure

```
DIYTypeless/
├── Domain/           # Protocols only
│   ├── Entities/
│   ├── Errors/
│   ├── Protocols/
│   ├── Repositories/
│   └── UseCases/
├── Data/             # Implementations
│   ├── Repositories/
│   └── UseCases/
├── State/            # @Observable ViewModels
├── Infrastructure/   # FFI, Scheduling
├── Presentation/     # SwiftUI Views
│   ├── DesignSystem/
│   └── Components/
├── Capsule/          # UI components
├── MenuBar/          # Menu bar UI
└── Onboarding/       # Onboarding UI
```
