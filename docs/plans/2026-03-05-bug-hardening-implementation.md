# Swift Bug-Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate stale async validation writes and stale hide timer writes in Swift state layer.

**Architecture:** Keep current Clean Architecture. Add localized synchronization guards in core state classes and verify with regression tests.

**Tech Stack:** Swift 5.10, Swift Concurrency, XCTest, SwiftPM + Xcode test lanes.

---

### Task 1: Reproduce stale onboarding validation overwrite

**Files:**
- Modify: `app/DIYTypeless/Tests/DIYTypelessCoreTests/OnboardingStateTests.swift`

**Step 1: Write the failing test**
- Add test where first refresh validation finishes after second refresh validation and would overwrite latest result.

**Step 2: Run test to verify it fails**
- Run: `cd app/DIYTypeless && swift test --filter OnboardingStateTests/testRefresh_whenEarlierRevalidationCompletesLast_doesNotOverrideLatestGroqValidation`
- Expected: FAIL (stale failure overrides latest success).

**Step 3: Implement minimal fix**
- Guard onboarding revalidation writes with a freshness token/session id.

**Step 4: Re-run test to verify pass**
- Same command, expected PASS.

### Task 2: Reproduce stale delayed hide overwrite

**Files:**
- Modify: `app/DIYTypeless/Tests/DIYTypelessCoreTests/RecordingStateTests.swift`

**Step 1: Write the failing test**
- Add test where two identical `.error` states are triggered; first timer must not hide second error early.

**Step 2: Run test to verify it fails**
- Run: `cd app/DIYTypeless && swift test --filter RecordingStateTests/testRepeatedSameError_doesNotHideEarlyFromStaleTimer`
- Expected: FAIL (capsule hides too early).

**Step 3: Implement minimal fix**
- Replace uncancelled delayed hide callbacks with cancellable scheduled work.

**Step 4: Re-run test to verify pass**
- Same command, expected PASS.

### Task 3: Keep regression safety for existing behavior

**Files:**
- Modify: `app/DIYTypeless/Sources/DIYTypelessCore/State/OnboardingState.swift`
- Modify: `app/DIYTypeless/Sources/DIYTypelessCore/State/RecordingState.swift`

**Step 1: Run focused suites**
- Run: `cd app/DIYTypeless && swift test --filter OnboardingStateTests`
- Run: `cd app/DIYTypeless && swift test --filter RecordingStateTests`

**Step 2: Fix any newly exposed regressions**
- Keep changes minimal and local.

### Task 4: Full verification before completion

**Files:**
- No code changes required unless verification fails.

**Step 1: SwiftPM tests**
- Run: `cd app/DIYTypeless && swift test`

**Step 2: Xcode scheme tests**
- Run: `cd app/DIYTypeless && xcodebuild -project DIYTypeless.xcodeproj -scheme DIYTypeless -configuration Debug -derivedDataPath ../../.context/DerivedData test -destination 'platform=macOS'`

**Step 3: Build loop verification**
- Run: `./scripts/dev-loop-build.sh --testing`

**Step 4: Report with evidence**
- Include exact pass/fail status and any remaining risk.
