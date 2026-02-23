# Button Styles Unification Plan

## Overview

**Goal**: Unify two parallel button style systems into a single, maintainable design system using semantic colors.

**Current Problem**:
- Two parallel button style systems exist: `ViewModifiers.swift` (legacy) and `ButtonStyles.swift` (enhanced)
- `ButtonStyles.swift` has Light Mode bugs (uses hardcoded `.white` opacity values)
- `ViewModifiers.swift` has 6 repeated `colorScheme == .dark` checks, violating DRY
- Hardcoded `Color.black/white` values are not semantic and fail accessibility standards

**Target State**:
- Single source of truth for button styles
- Semantic colors that auto-adapt to Light/Dark/High Contrast modes
- Zero hardcoded color scheme checks

## Architecture Constraints

- **Layer**: Presentation Layer only (DesignSystem)
- **Platform**: macOS (AppKit-based with SwiftUI)
- **Compatibility**: Must support Light Mode, Dark Mode, and High Contrast
- **Pattern**: Use `NSColor` semantic colors (e.g., `.quaternarySystemFill`) for automatic adaptation

## Files Involved

| File | Purpose | Action |
|------|---------|--------|
| `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ButtonStyles.swift` | Enhanced button styles (has Light Mode bug) | Fix and consolidate |
| `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ViewModifiers.swift` | Legacy button styles (repetitive colorScheme checks) | Deprecate and migrate |
| `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/Colors.swift` | Semantic color definitions | Extend with new semantic colors |

## Execution Plan

### Phase 1: Critical Fix (P0)
- [Task 001: Fix EnhancedSecondaryButtonStyle Light Mode Bug](./task-001-fix-enhanced-secondary-button-style.md)
  - Fix hardcoded `.white` opacity values in `ButtonStyles.swift`
  - Replace with semantic colors that auto-adapt

### Phase 2: System Unification (P1)
- [Task 002: Audit Button Style Usage](./task-002-audit-button-usage.md)
  - Find all usages of both button style systems
  - Map migration paths

- [Task 003: Extend Semantic Color System](./task-003-extend-semantic-colors.md)
  - Add button-specific semantic colors to `Colors.swift`
  - Define pressed, hovered, disabled state colors

- [Task 004: Consolidate Button Styles](./task-004-consolidate-button-styles.md)
  - Merge useful features from both systems
  - Create unified button style API

- [Task 005: Deprecate Legacy Button Styles](./task-005-deprecate-legacy-styles.md)
  - Mark old styles as deprecated
  - Add migration warnings

### Phase 3: Refactoring (P2)
- [Task 006: Migrate All Call Sites](./task-006-migrate-call-sites.md)
  - Update all views to use unified button styles
  - Remove deprecated style usages

- [Task 007: Remove Legacy ViewModifiers](./task-007-remove-legacy-viewmodifiers.md)
  - Delete deprecated button styles from `ViewModifiers.swift`
  - Keep non-button modifiers (Glassmorphism, CardContainer, etc.)

## Verification Strategy

1. **Visual Testing**: Build and verify in both Light and Dark modes
2. **Build Verification**: Use `./scripts/dev-loop.sh --testing` to ensure no compilation errors
3. **Usage Audit**: Grep for deprecated style names to ensure complete migration

## Success Criteria

- [ ] No hardcoded `Color.black` or `Color.white` for button backgrounds
- [ ] No `colorScheme == .dark` checks in button styles
- [ ] Single button style system in use across the app
- [ ] All buttons render correctly in Light Mode, Dark Mode, and High Contrast
- [ ] Zero compiler warnings for deprecated styles
