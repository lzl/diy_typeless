# Task 004: Consolidate Button Styles

**Priority**: P1 (High)
**Scope**: `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ButtonStyles.swift`
**Estimated Time**: 90 minutes

## Objective

Create a unified button style system that combines the best features of both legacy and enhanced styles.

## Analysis

### Legacy System (ViewModifiers.swift)
- `PrimaryButtonStyle` - Basic, no disabled state support
- `SecondaryButtonStyle` - Has colorScheme checks (6 times), Light/Dark aware
- `GhostButtonStyle` - Minimal, transparent background
- `IconButtonStyle` - Circular icon buttons

### Enhanced System (ButtonStyles.swift)
- `EnhancedPrimaryButtonStyle` - Full disabled state, animations
- `EnhancedSecondaryButtonStyle` - Full disabled state, Light Mode bug
- `DestructiveButtonStyle` - Red-themed for dangerous actions
- `EnhancedIconButtonStyle` - Enhanced icon buttons with borders
- `MenuBarButtonStyle` - Menu-specific styling

## Consolidation Strategy

### Unified API Design

Replace both systems with a single set of styles:

```swift
// Unified styles (in ButtonStyles.swift)
.primaryButton()        // Replaces both PrimaryButtonStyle and EnhancedPrimaryButtonStyle
.secondaryButton()      // Replaces both SecondaryButtonStyle and EnhancedSecondaryButtonStyle
.ghostButton()          // Keeps GhostButtonStyle
.iconButton()           // Replaces both IconButtonStyle and EnhancedIconButtonStyle
.destructiveButton()    // Keeps DestructiveButtonStyle
.menuBarButton()        // Keeps MenuBarButtonStyle
```

## Implementation Steps

### Step 1: Design UnifiedPrimaryButtonStyle

Merge features:
- From Enhanced: Full `isEnabled` support, animations
- From Legacy: Semantic color usage (after Task 001 fix)

Requirements:
- Use `.brandPrimary` for background
- Support disabled state with reduced opacity
- Keep hover and pressed animations
- Use semantic colors only

### Step 2: Design UnifiedSecondaryButtonStyle

Requirements:
- Use new semantic colors from Task 003
- Support disabled state
- Hover/pressed states with proper contrast
- Border support using semantic colors

### Step 3: Design UnifiedIconButtonStyle

Merge features:
- From Enhanced: Border overlay, better animations
- From Legacy: Smaller default size (32 vs 36)

### Step 4: Update View Extensions

Consolidate extensions to point to unified styles:

```swift
extension View {
    func primaryButton() -> some View {
        buttonStyle(UnifiedPrimaryButtonStyle())
    }

    func secondaryButton() -> some View {
        buttonStyle(UnifiedSecondaryButtonStyle())
    }

    // ... etc
}
```

## Style Specifications

### UnifiedPrimaryButtonStyle

| State | Background | Foreground | Border | Scale | Opacity |
|-------|------------|------------|--------|-------|---------|
| Normal | `.brandPrimary` | `.white` | Clear | 1.0 | 1.0 |
| Hover | `.brandPrimaryLight` | `.white` | Clear | 1.0 | 1.0 |
| Pressed | `.brandPrimary` @ 0.7 | `.white` | Clear | 0.96 | 0.85 |
| Disabled | `.brandPrimary` @ 0.3 | `.textMuted` | Clear | 1.0 | 0.6 |

### UnifiedSecondaryButtonStyle

| State | Background | Foreground | Border | Scale | Opacity |
|-------|------------|------------|--------|-------|---------|
| Normal | `.buttonSecondaryBackground` | `.textPrimary` | `.buttonSecondaryBorder` | 1.0 | 1.0 |
| Hover | `.buttonSecondaryBackgroundHover` | `.textPrimary` | `.buttonSecondaryBorderHover` | 1.0 | 1.0 |
| Pressed | `.buttonSecondaryBackgroundPressed` | `.textPrimary` | `.buttonSecondaryBorderPressed` | 0.96 | 0.85 |
| Disabled | `.buttonSecondaryBackground` @ 0.5 | `.textMuted` | `.buttonSecondaryBorder` @ 0.5 | 1.0 | 0.5 |

## Verification

1. Build the project:
   ```bash
   ./scripts/dev-loop.sh --testing
   ```

2. Visual verification in both Light and Dark modes:
   - [ ] Primary button renders correctly
   - [ ] Secondary button renders correctly
   - [ ] Icon button renders correctly
   - [ ] Destructive button renders correctly
   - [ ] Menu bar button renders correctly
   - [ ] Ghost button renders correctly

3. Interaction verification:
   - [ ] Hover effects work
   - [ ] Pressed effects work
   - [ ] Disabled state renders correctly

## Dependencies

- **Depends on**: Task 001 (understand fixed EnhancedSecondaryButtonStyle), Task 003 (semantic colors)
- **Blocks**: Task 005 (deprecation), Task 006 (migration)

## Notes

- Keep the existing style structs as deprecated aliases initially
- Ensure animation timings match the enhanced versions
- Document any breaking changes in the API
