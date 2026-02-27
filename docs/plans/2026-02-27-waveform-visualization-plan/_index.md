# Waveform Visualization Implementation Plan

**Date:** 2026-02-27
**Status:** Ready for Execution
**Based on:** [Design Document](../2026-02-27-waveform-visualization-design/)

---

## Goal

Replace the existing HStack-based waveform with a GPU-accelerated Canvas-based system that:
- Achieves 60fps fluid animation using TimelineView
- Follows Clean Architecture principles (proper layer separation)
- Supports multiple renderer styles with runtime switching
- Maintains state across animation frames for smooth effects

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  WaveformRendering Protocol (uses GraphicsContext)   │   │
│  │  ┌──────────────────┐      ┌──────────────────┐     │   │
│  │  │FluidWaveformRenderer│   │BarWaveformRenderer│    │   │
│  │  │ (@MainActor class)  │   │ (@MainActor class)│    │   │
│  │  └──────────────────┘      └──────────────────┘     │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ▲                                   │
│  ┌──────────────────────┴─────────────────────────────┐    │
│  │       WaveformContainerView (caches renderer)      │    │
│  │         TimelineView + Canvas (GPU rendering)      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                           │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │ AudioLevelProviding │      │ WaveformStyle            │  │
│  │ Protocol (pure)     │      │ Enum (Sendable)          │  │
│  └─────────────────────┘      └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  ┌──────────────────────────┐      ┌──────────────────────┐ │
│  │    AudioLevelMonitor     │─────▶│    AVAudioEngine     │ │
│  │  (Concrete Implementation)│     │   (System Framework)  │ │
│  └──────────────────────────┘      └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Execution Plan

### Phase 1: Domain Layer (Foundation)

| # | Task | Description | BDD Scenarios |
|---|------|-------------|---------------|
| 001 | [Domain - AudioLevelProviding (Test)](./task-001-domain-audio-level-providing-test.md) | Tests for audio level protocol | Domain purity, Double usage |
| 002 | [Domain - AudioLevelProviding (Impl)](./task-002-domain-audio-level-providing-impl.md) | Implement pure protocol | Domain purity, Double usage |
| 003 | [Domain - WaveformStyle (Test)](./task-003-domain-waveform-style-test.md) | Tests for style enum | Sendable, default style |
| 004 | [Domain - WaveformStyle (Impl)](./task-004-domain-waveform-style-impl.md) | Implement style enum | Sendable, default style |

### Phase 2: Infrastructure Layer

| # | Task | Description | BDD Scenarios |
|---|------|-------------|---------------|
| 005 | [Infrastructure - AudioLevelMonitor (Test)](./task-005-infrastructure-audio-monitor-test.md) | Tests for audio monitor | Layer placement, real-time updates |
| 006 | [Infrastructure - AudioLevelMonitor (Impl)](./task-006-infrastructure-audio-monitor-impl.md) | Implement AVAudioEngine monitor | Layer placement, real-time updates |

### Phase 3: Presentation Layer (Core)

| # | Task | Description | BDD Scenarios |
|---|------|-------------|---------------|
| 007 | [Presentation - WaveformRendering Protocol (Test)](./task-007-presentation-waveform-rendering-protocol-test.md) | Tests for rendering protocol | Layer placement, GraphicsContext |
| 008 | [Presentation - WaveformRendering Protocol (Impl)](./task-008-presentation-waveform-rendering-protocol-impl.md) | Implement rendering protocol | Layer placement, GraphicsContext |
| 009 | [Presentation - FluidWaveformRenderer (Test)](./task-009-presentation-fluid-renderer-test.md) | Tests for fluid renderer | State persistence, style support |
| 010 | [Presentation - FluidWaveformRenderer (Impl)](./task-010-presentation-fluid-renderer-impl.md) | Implement Siri-like fluid renderer | State persistence, 60fps animation |
| 011 | [Presentation - BarWaveformRenderer (Test)](./task-011-presentation-bar-renderer-test.md) | Tests for bar renderer | Style support, empty handling |
| 012 | [Presentation - BarWaveformRenderer (Impl)](./task-012-presentation-bar-renderer-impl.md) | Implement legacy bar renderer | Style support |
| 013 | [Presentation - WaveformRendererFactory (Test)](./task-013-presentation-renderer-factory-test.md) | Tests for factory | Runtime selection, default style |
| 014 | [Presentation - WaveformRendererFactory (Impl)](./task-014-presentation-renderer-factory-impl.md) | Implement factory | Runtime selection |
| 015 | [Presentation - WaveformContainerView (Test)](./task-015-presentation-container-view-test.md) | Tests for container view | 60fps animation, renderer caching |
| 016 | [Presentation - WaveformContainerView (Impl)](./task-016-presentation-container-view-impl.md) | Implement TimelineView+Canvas | 60fps animation, renderer caching |
| 017 | [Presentation - WaveformSettings (Test)](./task-017-presentation-settings-test.md) | Tests for settings | @Observable without didSet |
| 018 | [Presentation - WaveformSettings (Impl)](./task-018-presentation-settings-impl.md) | Implement settings | @Observable without didSet |

### Phase 4: Integration & Testing

| # | Task | Description | BDD Scenarios |
|---|------|-------------|---------------|
| 019 | [Mocks and Test Helpers](./task-019-mocks-test-helpers.md) | Create test infrastructure | Preview support |
| 020 | [Capsule Integration (Test)](./task-020-capsule-integration-test.md) | Tests for capsule integration | Recording state, transitions |
| 021 | [Capsule Integration (Impl)](./task-021-capsule-integration-impl.md) | Integrate into capsule | Recording state, transitions |
| 022 | [Performance Verification](./task-022-performance-verification.md) | Verify 60fps, memory, CPU | Performance scenarios |
| 023 | [Edge Case Tests](./task-023-edge-case-tests.md) | Test edge cases | Silence, max, interruption |
| 024 | [Documentation](./task-024-documentation.md) | Create docs and final review | All BDD scenarios |

---

## Critical Architecture Rules

1. **No CGFloat in Domain Layer**: Use `Double` throughout Domain, convert to CGFloat only in Canvas
2. **No SwiftUI in Domain Layer**: Domain must only import Foundation
3. **@MainActor Classes for Renderers**: NOT structs - state must persist across frames
4. **Renderer Caching in @State**: Do NOT create new renderer in Canvas closure
5. **No didSet in @Observable**: Use computed properties with get/set instead

---

## Dependencies Graph

```
001 → 002 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015 → 016 → 017 → 018 → 019 → 020 → 021 → 022 → 023 → 024
      ↑
003 → 004 ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

All tasks are sequential except 003/004 which can run in parallel with 001/002.

---

## Success Criteria

### Performance Metrics

| Metric | Target |
|--------|--------|
| Animation Frame Rate | >= 60fps |
| CPU Usage | < 5% on M1 Mac |
| Memory Growth | Zero over 10min |
| Main Thread Blocking | None |

### Code Quality

| Criterion | Target |
|-----------|--------|
| Architecture Compliance | All layers properly separated |
| Renderer LOC | < 100 lines each |
| Test Coverage | > 90% for new components |
| Build Time Impact | < 5% increase |

---

## Verification Command

```bash
# Build and run all tests
./scripts/dev-loop-build.sh --testing
```

---

## Next Steps

This plan is ready for execution using `superpowers:executing-plans`.
