# Task 002: Semantic Colors for Dark/Light Mode

**BDD Scenario**: Scenario 2 - Color system supports dark/light mode

## Goal

Update Colors.swift to use semantic system colors for backgrounds and text, while keeping brand colors hardcoded.

## Acceptance Criteria

- [ ] `appBackground` uses `Color(nsColor: .windowBackgroundColor)` with appropriate opacity
- [ ] `textPrimary` uses `Color(nsColor: .label)`
- [ ] `textSecondary` uses `Color(nsColor: .secondaryLabel)`
- [ ] `glassBackground` uses `.ultraThinMaterial` approach
- [ ] Brand colors (brandPrimary, brandAccent, success) remain hardcoded as designed
- [ ] App adapts automatically when system appearance changes

## Files to Modify

- `app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/Colors.swift`

## Verification

```bash
./scripts/dev-loop-build.sh --testing
```

Build should pass. Manual verification: toggle macOS appearance and observe capsule window.

## Dependencies

None

## Commit Boundary

Single commit for this task:
```
refactor(design): use semantic colors for dark/light mode support
```
