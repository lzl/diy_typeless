# Option 3 Core Module Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promote the current headless Swift test harness into a first-class core module boundary for critical logic, with tests targeting that module directly.

**Architecture:** Keep production source-of-truth files in `app/DIYTypeless/DIYTypeless`, compile critical components through a dedicated SwiftPM module, and keep the macOS app build path unchanged. This delivers a stable module boundary for tests now and a safe migration base for app-level dependency inversion later.

**Tech Stack:** Swift 5.10, SwiftPM, XCTest, xcodebuild.

---

### Task 1: Formalize Module Naming

**Files:**
- Modify: `app/DIYTypeless/Package.swift`

**Step 1: Rename package product/target/test target from headless naming to core-module naming**

Apply rename:
- `DIYTypelessHeadlessCore` -> `DIYTypelessCore`
- `DIYTypelessHeadlessCoreTests` -> `DIYTypelessCoreTests`

**Step 2: Run package tests to verify module resolution**

Run: `cd app/DIYTypeless && swift test`
Expected: all existing gold-standard tests pass.

### Task 2: Align Shared Test Sources to the Core Module

**Files:**
- Modify: `app/DIYTypeless/DIYTypelessTests/RecordingStateTests.swift`
- Modify: `app/DIYTypeless/DIYTypelessTests/OnboardingStateTests.swift`
- Modify: `app/DIYTypeless/DIYTypelessTests/ProcessVoiceCommandUseCaseImplTests.swift`
- Modify: `app/DIYTypeless/DIYTypelessTests/CoreErrorMapperTests.swift`
- Modify: `app/DIYTypeless/DIYTypelessTests/TranscriptionUseCaseTests.swift`
- Modify: `app/DIYTypeless/DIYTypelessTests/TestDoubles.swift`

**Step 1: Update conditional imports to prioritize `DIYTypelessCore` package module**

Use fallback order:
1. `DIYTypeless` (Xcode app target)
2. `DIYTypelessCore` (SwiftPM core module)

**Step 2: Run package tests again**

Run: `cd app/DIYTypeless && swift test`
Expected: all tests pass with module rename.

### Task 3: Document Option-3 Boundary

**Files:**
- Modify: `docs/swift-testing-gold-standard.md`
- Create: `docs/swift-core-module-boundary.md`

**Step 1: Update gold-standard doc**

Add:
- `DIYTypelessCore` as canonical core test module
- rationale for module boundary vs hosted app tests
- explicit command for core module tests

**Step 2: Add boundary document**

Include:
- what belongs in core module
- what remains app/integration layer
- migration checklist for app target to depend on core module in future phases

### Task 4: Verify Required Build Paths

**Files:**
- None

**Step 1: Verify core module test lane**

Run: `cd app/DIYTypeless && swift test`
Expected: pass.

**Step 2: Verify required app build loop**

Run: `./scripts/dev-loop-build.sh --testing`
Expected: build succeeds.

### Task 5: Commit

**Files:** all above

**Step 1: Commit with Conventional Commit**

Run:
- `git add ...`
- `git commit -m "refactor(swift): establish diytypelesscore module boundary"`

**Step 2: Report evidence**

Include:
- `swift test` summary
- `dev-loop-build.sh --testing` result
- note any remaining hosted xcode test target limitations
