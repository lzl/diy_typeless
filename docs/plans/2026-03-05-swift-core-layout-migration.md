# Swift Core Layout Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move headless core/test code to canonical SwiftPM `Sources/` and `Tests/` layout while preserving existing app behavior and verification paths.

**Architecture:** Keep core source-of-truth files shared by both SwiftPM and Xcode app build, but relocate them under canonical package paths. Retain app/UI and macOS integration code in `app/DIYTypeless/DIYTypeless`, and keep FFI-generated bindings in app layer.

**Tech Stack:** Swift 5.10, SwiftPM, Xcode project file-system synchronized groups, XCTest.

---

### Task 1: Create canonical package directories

**Files:**
- Create: `app/DIYTypeless/Sources/DIYTypelessCore/`
- Create: `app/DIYTypeless/Tests/DIYTypelessCoreTests/`

**Step 1: Prepare destination folders**

Run:
```bash
mkdir -p app/DIYTypeless/Sources/DIYTypelessCore
mkdir -p app/DIYTypeless/Tests/DIYTypelessCoreTests
```

**Step 2: Ensure old package-only build artifacts are out of versioned tree**

Run:
```bash
git status --short
```
Expected: no staged build artifacts.

### Task 2: Relocate core source files

**Files:**
- Move: `app/DIYTypeless/DIYTypeless/Domain/**` -> `app/DIYTypeless/Sources/DIYTypelessCore/Domain/**`
- Move: `app/DIYTypeless/DIYTypeless/State/OnboardingState.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/State/OnboardingState.swift`
- Move: `app/DIYTypeless/DIYTypeless/State/RecordingState.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/State/RecordingState.swift`
- Move: `app/DIYTypeless/DIYTypeless/State/VoiceCommandResultLayerState.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/State/VoiceCommandResultLayerState.swift`
- Move: `app/DIYTypeless/DIYTypeless/Data/UseCases/ProcessVoiceCommandUseCaseImpl.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/Data/UseCases/ProcessVoiceCommandUseCaseImpl.swift`
- Move: `app/DIYTypeless/DIYTypeless/Infrastructure/Scheduling/RealPrefetchScheduler.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/Infrastructure/Scheduling/RealPrefetchScheduler.swift`
- Move: `app/DIYTypeless/DIYTypeless/Infrastructure/Headless/SwiftPackageShims.swift` -> `app/DIYTypeless/Sources/DIYTypelessCore/Infrastructure/Headless/SwiftPackageShims.swift`

**Step 1: Move directories/files preserving names**

Run shell moves for all listed paths.

**Step 2: Keep app-only files in place**

Do not move SwiftUI views, app entry points, FFI generated files, or macOS system repository implementations.

### Task 3: Relocate package tests

**Files:**
- Move: `app/DIYTypeless/DIYTypelessTests/*.swift` -> `app/DIYTypeless/Tests/DIYTypelessCoreTests/*.swift`

**Step 1: Move current gold-standard test suite files**

Move all six test files currently used by SwiftPM target.

**Step 2: Verify test imports still resolve module fallback order**

Run:
```bash
rg -n "canImport\(DIYTypeless\)|canImport\(DIYTypelessCore\)" app/DIYTypeless/Tests/DIYTypelessCoreTests
```
Expected: fallback import guards remain intact.

### Task 4: Simplify SwiftPM manifest

**Files:**
- Modify: `app/DIYTypeless/Package.swift`

**Step 1: Switch to canonical path-based target definitions**

Use:
- target path `Sources/DIYTypelessCore`
- test target path `Tests/DIYTypelessCoreTests`

**Step 2: Remove manual per-file source lists**

Rely on folder structure to avoid “unhandled files” warnings and improve maintainability.

### Task 5: Update Xcode project synchronized groups

**Files:**
- Modify: `app/DIYTypeless/DIYTypeless.xcodeproj/project.pbxproj`

**Step 1: Add synchronized root group for core sources**

Add file-system synchronized group for `Sources/DIYTypelessCore` and include it in app target synchronized groups.

**Step 2: Repoint test synchronized group path**

Update existing test group path from `DIYTypelessTests` to `Tests/DIYTypelessCoreTests`.

### Task 6: Verification

**Files:** none

**Step 1: Verify SwiftPM lane**

Run:
```bash
cd app/DIYTypeless
swift test
```
Expected: all core tests pass, and prior unhandled-file warning is removed.

**Step 2: Verify app build lane**

Run:
```bash
cd /Users/lzl/Documents/GitHub/diy_typeless
./scripts/dev-loop-build.sh --testing
```
Expected: build succeeds.

### Task 7: Commit

**Files:** all changed files from tasks above

**Step 1: Commit with Conventional Commit**

```bash
git add app/DIYTypeless docs/plans/2026-03-05-swift-core-layout-migration.md
git commit -m "refactor(swift): migrate core to canonical swiftpm layout"
```

**Step 2: Report evidence**

Include:
- `swift test` pass summary
- `dev-loop-build.sh --testing` success
- notes on remaining architecture follow-up work (if any)
