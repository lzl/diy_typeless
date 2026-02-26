# Test Coverage Gap Analysis & Improvement Plan

**Created**: 2026-02-26
**Status**: Draft
**Purpose**: Document test coverage gaps to enable AI agents to improve testing infrastructure

---

## Executive Summary

Current project has **uneven test coverage**:
- Swift State/UseCase layer: **Good** (RecordingState has 12+ comprehensive tests)
- Rust Core: **None** (zero unit tests)
- CLI: **None** (zero tests)
- Swift Data/Repository layer: **Partial** (few integration tests)

This gap prevents AI agents from safely modifying deep modules (Rust core) because there's no automated verification of behavior changes.

---

## Current Test Inventory

### Swift Layer

| Module | Location | Test Files | Coverage |
|--------|----------|------------|----------|
| Domain/UseCases | `Domain/UseCases/` | 3 test files | Basic validation tests |
| State | `State/RecordingState.swift` | `RecordingStateTests.swift` | **Comprehensive** (12+ tests covering concurrency, cancellation, prefetch) |
| Data/UseCases | `Data/UseCases/` | 0 dedicated tests | None (covered by State tests via mocking) |
| Data/Repositories | `Data/Repositories/` | 0 tests | None |
| Presentation | `Presentation/` | 0 tests | None |

### Rust Layer

| Module | Location | Test Files | Coverage |
|--------|----------|------------|----------|
| audio.rs | `core/src/` (380 LOC) | 0 | **None** |
| llm_processor.rs | `core/src/` (136 LOC) | 0 | **None** |
| http_client.rs | `core/src/` (75 LOC) | 0 | **None** |
| transcribe.rs | `core/src/` (75 LOC) | 0 | **None** |
| polish.rs | `core/src/` (102 LOC) | 0 | **None** |
| config.rs | `core/src/` (11 LOC) | 0 | **None** |
| error.rs | `core/src/` (39 LOC) | 0 | **None** |

### CLI Layer

| Module | Location | Test Files | Coverage |
|--------|----------|------------|----------|
| CLI main.rs | `cli/src/` | 0 | **None** |
| CLI commands | `cli/src/commands/` | 0 | **None** |

---

## Problem Analysis

### Problem 1: Rust Core Has Zero Tests

**Impact**: Critical
**Root Cause**: Project was built iteratively without TDD discipline for Rust layer

**Specific Risks**:
- `audio.rs`: Audio level calculation algorithm (RMS, dB conversion) has no verification
- `llm_processor.rs`: Retry logic, error handling, response parsing untested
- `http_client.rs`: HTTP header construction, timeout handling untested
- `polish.rs`: Prompt template substitution untested

**Why This Matters for AI Collaboration**:
- AI cannot modify these modules without risking silent regressions
- No way to verify AI-generated changes are correct
- CLAUDE.md requires "closing the loop via CLI" but CLI has no automated tests

### Problem 2: CLI Has No Test Coverage

**Impact**: High
**Root Cause**: CLI was built as validation tool, not production code

**Specific Risks**:
- Command-line argument parsing untested
- Error handling paths untested
- File I/O operations untested

**Why This Matters for AI Collaboration**:
- AI may extend CLI without proper error handling
- Cannot verify CLI behavior after Rust core changes

### Problem 3: Swift Data Layer Lacks Integration Tests

**Impact**: Medium
**Root Cause**: Focus on State/UseCase unit tests, skipped integration tests

**Specific Risks**:
- Repository implementations (Keychain, Accessibility, etc.) untested
- SwiftData models untested
- FFI bridge behavior untested

**Why This Matters for AI Collaboration**:
- AI adding new Repository implementations has no guidance
- Cannot catch Swift-Rust interface mismatches

### Problem 4: Test Infrastructure Is Incomplete

**Impact**: Medium

**Current State**:
- Mock files exist in `DIYTypelessTests/State/` and `DIYTypelessTests/Mocks/`
- No shared test utilities package
- No test factory patterns for creating consistent test data

**Required**:
- Standardized mock factories for all Domain protocols
- Test data builders for entities
- Shared concurrency test helpers (already exists: `ConcurrencyTestHelpers.swift`)

---

## Improvement Requirements

### Priority 0: Rust Core Unit Tests

**Goal**: Add basic unit tests for all Rust core modules

**Requirements**:

1. **audio.rs tests**
   - Test `calculate_rms_db()` function with known inputs
   - Test `apply_highpass_filter()` with synthetic audio data
   - Test sample rate conversion logic

2. **llm_processor.rs tests**
   - Test retry logic (max retries, backoff)
   - Test error classification
   - Test response parsing with mock HTTP responses

3. **http_client.rs tests**
   - Test header construction
   - Test timeout handling (mock server)
   - Test error response parsing

4. **polish.rs tests**
   - Test prompt template substitution
   - Test context insertion
   - Test empty/whitespace input handling

**Constraints**:
- Use `#[cfg(test)]` inline modules (not separate files)
- Use `mockito` or similar for HTTP mocking
- Keep tests fast (<100ms each)
- All tests must pass in CI

### Priority 1: CLI Integration Tests

**Goal**: Add basic CLI smoke tests

**Requirements**:

1. Test `diy-typeless record --help` outputs correct help
2. Test `diy-typeless transcribe --help` outputs correct help
3. Test `diy-typeless polish --help` outputs correct help
4. Test `diy-typeless full --help` outputs correct help
5. Test `diy-typeless diagnose env` runs without error
6. Test invalid arguments produce helpful errors

**Constraints**:
- Use `assert_cmd` crate for CLI testing
- Mock external dependencies (audio device, API keys)
- Tests must work in CI without interactive input

### Priority 2: Swift Data Layer Integration Tests

**Goal**: Add integration tests for Repository implementations

**Requirements**:

1. **KeychainApiKeyRepository**
   - Test save/load key round-trip
   - Test delete key
   - Test key not found case

2. **AccessibilitySelectedTextRepository**
   - Test get selected text from mock accessibility API

3. **SystemPermissionRepository**
   - Test permission check logic

**Constraints**:
- Use `@MainActor` for all tests
- Mock system APIs (Accessibility, Keychain)
- Do NOT require actual system permissions to run

### Priority 3: Test Infrastructure Improvements

**Goal**: Standardize test patterns for AI agents

**Requirements**:

1. Create test factory for all Domain entities
2. Document mock patterns in AGENTS.md
3. Add test naming convention to AGENTS.md

---

## Success Criteria

| Priority | Metric | Target |
|----------|--------|--------|
| P0 | Rust core test coverage | >60% line coverage |
| P0 | Rust core test count | >20 test functions |
| P1 | CLI test count | >5 integration tests |
| P2 | Repository integration tests | >3 tests per Repository |
| P3 | Test factory availability | All entities have factories |

---

## Agent Instructions

When implementing test improvements:

1. **Start with Rust core** - it's the most critical gap
2. **Use existing test patterns** - RecordingStateTests.swift shows the expected quality
3. **Keep tests independent** - no ordering dependencies
4. **Use descriptive test names** - follow `testXxx_Yyy_Zzz` pattern
5. **Add doc comments** - explain what each test verifies
6. **Run tests locally** - use `cargo test` before committing

---

## References

- CLAUDE.md: "Closing the Loop" requirement
- `tests/polish-prompt/` - Example of behavior-driven test structure
- `DIYTypelessTests/State/RecordingStateTests.swift` - Reference for Swift test quality