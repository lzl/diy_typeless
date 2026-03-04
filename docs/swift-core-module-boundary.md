# Swift Core Module Boundary

## Purpose

This document defines the option-3 architecture boundary for Swift testing and long-term maintainability.

`DIYTypelessCore` is the canonical module for business-critical logic that must be testable without launching the macOS app host.

## Module Ownership

`DIYTypelessCore` owns:

- domain entities, errors, repository protocols
- domain use-case protocols and orchestration logic
- critical state coordinators used by the primary user flow (`RecordingState`, `OnboardingState`)
- deterministic scheduling abstraction for testability

The app target owns:

- SwiftUI views and visual components
- macOS integration infrastructure (windowing, permissions UI flow, menu bar wiring)
- concrete repository implementations that touch system APIs

## Why This Boundary Matters

- avoids host-process coupling for core regression tests
- provides deterministic, fast verification for high-risk logic
- reduces linker/test-host fragility from app target test wiring
- creates a clean migration path toward explicit architecture layers

## Current Implementation

- Module: `DIYTypelessCore` in `app/DIYTypeless/Package.swift`
- Tests run against that module via:

```bash
cd app/DIYTypeless
swift test
```

- FFI-backed types required only for compilation in package context are provided by package-only shims:
  - `DIYTypeless/Infrastructure/Headless/SwiftPackageShims.swift`

## Migration Checklist (App -> Core Module Dependency)

1. Import `DIYTypelessCore` from app target sources that consume core types.
2. Stop compiling core-owned source files directly in app target.
3. Keep platform/system implementations in app layer and conform to core protocols.
4. Keep `swift test` as the primary regression lane for core logic.
5. Preserve app build verification with `./scripts/dev-loop-build.sh --testing`.

## Verification Contract

Any change to core-owned logic must pass both:

```bash
cd app/DIYTypeless
swift test

cd /path/to/repo/root
./scripts/dev-loop-build.sh --testing
```
