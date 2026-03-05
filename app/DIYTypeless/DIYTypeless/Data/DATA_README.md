# Data Layer

This layer contains **app-specific concrete implementations** of protocols defined in `DIYTypelessCore` Domain. It bridges core logic with macOS-only systems (Keychain, Accessibility APIs, AppKit event/output APIs).

## Purpose

- Implement Domain protocols with real-world functionality
- Handle infrastructure concerns (Keychain and system APIs)
- Keep external dependencies isolated from business logic

## Subdirectories

### Repositories/
Concrete implementations of Domain repository protocols.

| Implementation | Protocol | External Dependency |
|----------------|----------|---------------------|
| `KeychainApiKeyRepository` | ApiKeyRepository | macOS Keychain |
| `DefaultAppContextRepository` | AppContextRepository | NSWorkspace |
| `AccessibilitySelectedTextRepository` | SelectedTextRepository | Accessibility API |
| `SystemKeyMonitoringRepository` | KeyMonitoringRepository | NSEvent |
| `SystemPermissionRepository` | PermissionRepository | AXIsProcessTrusted |
| `SystemTextOutputRepository` | TextOutputRepository | CGEvent |
| `NSWorkspaceExternalLinkRepository` | ExternalLinkRepository | NSWorkspace |

### UseCases/
Use case implementations were migrated into `DIYTypelessCore` package and are no longer owned by the app target.

Current package location:
- `app/DIYTypeless/Sources/DIYTypelessCore/Data/UseCases/`

## Key Principles

1. **Implement Domain protocols** - Never define new protocols here
2. **External dependencies** - Keychain, Network, System APIs
3. **Async/await** - Use Swift concurrency for async operations
4. **Core delegation** - Rust/LLM-backed behavior lives in `DIYTypelessCore`

## Usage

When AI needs to modify how something works:
1. Find the Domain protocol first to understand the interface
2. Then look here for the implementation details
3. Check app FFI bootstrap (`Infrastructure/FFI/CoreFFIRuntimeBootstrap.swift`) only for app-to-core runtime binding

## Important Notes

- Audio transcription/polishing/LLM calls are handled by `DIYTypelessCore` via injected FFI runtime handlers
- App layer focuses on system integration (permissions, selected text, key monitoring, output routing)
- Keychain access uses Security framework
