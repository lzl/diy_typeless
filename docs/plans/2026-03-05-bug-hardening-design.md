# Swift App Bug-Hardening Design

**Date:** 2026-03-05

## Goal
Raise the Swift app architecture from "good" to "hard to make bugs" by hardening async state handling and lifecycle-sensitive transitions.

## Scope
- Keep existing clean architecture and module boundaries.
- Harden high-risk async flows in `OnboardingState` and `RecordingState`.
- Add regression tests for stale async results and stale timers.
- Avoid broad refactors that increase migration risk.

## Problem Summary
Current code has two practical bug vectors:
1. `OnboardingState.refresh()` launches untracked revalidation tasks; older task results can override newer state.
2. `RecordingState.scheduleHide` uses uncancelled delayed closures; older hides can clear newer identical states early.

These are classic race/lifecycle defects that are hard to catch manually.

## Chosen Approach (Incremental Hardening)
1. Add regression tests first for both race classes.
2. Introduce validation session guarding in `OnboardingState` so only latest refresh/validation writes state.
3. Introduce cancellable hide scheduling in `RecordingState` so superseded delayed hides cannot fire.
4. Keep public APIs stable and preserve user-visible behavior except bug fixes.

## Tradeoffs
- Pros: Small surface area, low regression risk, immediate reliability gain.
- Cons: Does not fully decompose large state objects yet.
- Accepted: This is the best reliability-per-change ratio now.

## Verification Strategy
Run complete required matrix after changes:
1. `cd app/DIYTypeless && swift test`
2. `cd app/DIYTypeless && xcodebuild -project DIYTypeless.xcodeproj -scheme DIYTypeless -configuration Debug -derivedDataPath ../../.context/DerivedData test -destination 'platform=macOS'`
3. `./scripts/dev-loop-build.sh --testing`

## Non-Goals
- No architecture rewrite to reducer/state-machine in this pass.
- No UI redesign.
- No API-level behavior changes outside bug hardening.
