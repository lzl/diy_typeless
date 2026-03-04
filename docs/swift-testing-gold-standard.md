# Swift Testing Gold Standard

## Purpose

This document explains:

1. Why we selected the current Swift test suites as the benchmark baseline.
2. What each suite validates and why it matters to product reliability.

The goal is to keep future Swift tests aligned with business-critical behavior, not just line coverage.

## Why These Tests Were Chosen

We prioritized tests by user impact and failure cost.

### 1. `RecordingState` is the app's operational core

`RecordingState` coordinates the full push-to-talk lifecycle:

- permission/key gating before recording
- recording start/stop
- mode switching (voice-command mode vs transcription/polish mode)
- cancellation semantics
- output delivery state transitions

A regression here breaks the primary product loop immediately.

### 2. `OnboardingState` controls readiness and conversion

`OnboardingState` is the gatekeeper for:

- permission progression
- API key validation behavior
- step navigation correctness

If onboarding logic regresses, users cannot reach the usable state even if the rest of the pipeline works.

### 3. Error mapping defines user-visible reliability

`ProcessVoiceCommandUseCaseImpl` and `CoreErrorMapper` turn technical failures into user-facing outcomes. Testing these mappings prevents silent UX regressions where errors become misleading or unactionable.

### 4. `TranscriptionUseCase` protects composition contracts

`TranscriptionUseCase` is a facade pipeline. It must preserve call order and error propagation between stop -> transcribe -> polish.

## Test Inventory (Current Baseline)

Total: **22 tests**

### `RecordingStateTests` (6 tests)

Covers:

- permission-missing path -> onboarding request + error state
- happy-path key-down start behavior
- selected-text path -> voice-command mode
- no-selection path -> polish + output delivery
- cancellation while processing
- deactivation reset behavior

Why this matters: validates the highest-risk async state machine in the app.

### `OnboardingStateTests` (5 tests)

Covers:

- completion-step sync when prerequisites are already satisfied
- empty key validation message behavior
- successful key validation and trimmed persistence
- provider validation failure message mapping
- key edit resetting validation state

Why this matters: prevents onboarding dead-ends and invalid readiness transitions.

### `ProcessVoiceCommandUseCaseImplTests` (5 tests)

Covers:

- successful execution + prompt construction
- pre-cancel token behavior
- CoreError `.Api(401)` mapping
- CoreError `.Http` mapping
- CoreError `.Cancelled` behavior

Why this matters: ensures command processing returns the right action and trustworthy user errors.

### `CoreErrorMapperTests` (4 tests)

Covers:

- common API status code mappings
- unknown API messages
- network category mapping
- unknown category mapping

Why this matters: locks error semantics that drive UI messaging.

### `TranscriptionUseCaseTests` (2 tests)

Covers:

- happy-path composition and parameter propagation
- early stop-recording failure propagation and downstream skip

Why this matters: protects orchestration guarantees across use-case boundaries.

## What Makes This the "Gold Standard"

These suites intentionally enforce:

- **Behavior-first assertions** over implementation detail checks.
- **Deterministic async tests** via isolated mocks/spies.
- **Clear scenario naming** in `test_<when>_<then>` style.
- **Strict boundary testing** at state/use-case edges.
- **Failure-mode coverage** for cancellation and error mapping.

Future Swift tests should follow the same principles.

## Run Commands

```bash
# Headless gold-standard tests (option 2, no app host launch)
cd app/DIYTypeless
swift test

# Run Swift app tests
xcodebuild -project app/DIYTypeless/DIYTypeless.xcodeproj \
  -scheme DIYTypeless \
  -configuration Debug \
  -derivedDataPath .context/DerivedData \
  test -destination 'platform=macOS'

# Build verification loop required by project workflow
./scripts/dev-loop-build.sh --testing
```

## Why Headless Testing Was Added

The new headless path runs the same gold-standard suites without launching the macOS app host process. This matters because it:

- reduces feedback loop time for core state/use-case logic
- removes host-app/runtime noise from domain-level regression checks
- enables deterministic CI checks on business-critical behavior
- keeps app-hosted tests available for integration confidence

Implementation detail: the headless workflow uses `app/DIYTypeless/Package.swift` and compiles the same production source files under test, with Swift Package-only shims for FFI-only types required at compile time (`CancellationToken`, `CoreError`).

## Files Under Test

- `app/DIYTypeless/DIYTypeless/State/RecordingState.swift`
- `app/DIYTypeless/DIYTypeless/State/OnboardingState.swift`
- `app/DIYTypeless/DIYTypeless/Data/UseCases/ProcessVoiceCommandUseCaseImpl.swift`
- `app/DIYTypeless/DIYTypeless/Domain/Errors/CoreErrorMapper.swift`
- `app/DIYTypeless/DIYTypeless/Domain/UseCases/TranscriptionUseCase.swift`

## Test Suite Files

- `app/DIYTypeless/DIYTypelessTests/RecordingStateTests.swift`
- `app/DIYTypeless/DIYTypelessTests/OnboardingStateTests.swift`
- `app/DIYTypeless/DIYTypelessTests/ProcessVoiceCommandUseCaseImplTests.swift`
- `app/DIYTypeless/DIYTypelessTests/CoreErrorMapperTests.swift`
- `app/DIYTypeless/DIYTypelessTests/TranscriptionUseCaseTests.swift`
- `app/DIYTypeless/DIYTypelessTests/TestDoubles.swift`
