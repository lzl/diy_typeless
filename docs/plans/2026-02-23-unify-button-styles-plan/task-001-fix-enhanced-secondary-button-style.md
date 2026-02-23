# Task 001: Fix EnhancedSecondaryButtonStyle Light Mode Bug

**Priority**: P0 (Critical)
**Scope**: `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ButtonStyles.swift`
**Estimated Time**: 30 minutes

## Problem Statement

`EnhancedSecondaryButtonStyle` in `ButtonStyles.swift` uses hardcoded `.white` opacity values for background and border colors:

```swift
private func backgroundColor(for configuration: Configuration) -> Color {
    if !isEnabled {
        return .white.opacity(0.05)  // BUG: Always white, breaks Light Mode
    }
    // ...
}
```

This causes buttons to be invisible or poorly visible in Light Mode.

## Solution

Replace hardcoded `.white` with semantic colors that automatically adapt:

```swift
.background(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color(nsColor: .quaternarySystemFill))  // Auto-adapts to mode
)
```

## Implementation Steps

1. Open `ButtonStyles.swift`
2. Locate `EnhancedSecondaryButtonStyle` struct (lines 79-148)
3. Replace the following methods:
   - `backgroundColor(for:)` - Use `.quaternarySystemFill` with opacity adjustments
   - `borderColor(for:)` - Use `.separatorColor` or `.quaternaryLabelColor`
4. Ensure the style works correctly for:
   - Normal state
   - Hover state (slightly darker/lighter)
   - Pressed state (more contrast)
   - Disabled state (reduced opacity)

## Color Mapping Reference

| Current (Broken) | Replacement (Semantic) |
|------------------|------------------------|
| `.white.opacity(0.08)` | `Color(nsColor: .quaternarySystemFill)` |
| `.white.opacity(0.12)` | `Color(nsColor: .tertiarySystemFill)` |
| `.white.opacity(0.15)` | `Color(nsColor: .secondarySystemFill)` |
| `.white.opacity(0.1)` (border) | `Color(nsColor: .separatorColor)` |

## Verification

1. Build the project:
   ```bash
   ./scripts/dev-loop.sh --testing
   ```

2. Visual verification checklist:
   - [ ] Button visible in Light Mode
   - [ ] Button visible in Dark Mode
   - [ ] Hover state shows visual feedback
   - [ ] Pressed state shows visual feedback
   - [ ] Disabled state shows reduced opacity

## Dependencies

None - this is the first task.

## Notes

- Do NOT change the animation or scale effects - only fix colors
- Keep the same corner radius (8) and style (.continuous)
- The `isEnabled` check logic should remain, only the color values change
